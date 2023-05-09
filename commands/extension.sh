#!/bin/bash

# This is the extension command script for the ukit tool.
#
# Copyright 2023 Valentin LEFEBVRE <valentin.lefebvre@suse.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#######################################################################
#                           GLOBAL VARIABLES                          #
#######################################################################

EXTENSION_TYPE_DEFAULT="raw"
EXTENSION_FORMAT_DEFAULT="ext4"
EXTENSION_PART_UUID="0fc63daf-8483-4772-8e79-3d69d8477de4"
EXTENSION_PART_LABEL="Linux filesystem"
EXTENSION_LIST_DEPS=()
EXTENSION_LSINITRD=""
EXTENSION_INITRD_RELEASE=""

#######################################################################
#                       PRIVATE FUNCTIONS                             #
#######################################################################

###
# List all deps of a package recursively
# ARGUMENTS:
#   1 - package's name
# VARIABLES:
#   EXTENSION_LIST_DEPS
# RETURN:
#   None
###
function _extension_deps_packages() {
    local pkg="$1"
    local found=0
    while IFS= read -r require; do
        dep_pkg=$(rpm -q --whatprovides "$require")
        if [ $? -eq 1 ]; then
            continue
        fi
        for elem in "${EXTENSION_LIST_DEPS[@]}"; do
            if [ "$elem" == "$dep_pkg" ]; then
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            EXTENSION_LIST_DEPS+=("$dep_pkg")
            _extension_deps_packages "$dep_pkg"
        else
            found=0
        fi
    done < <(rpm -qR "$pkg")
}

#######################################################################
#                       MAIN FUNCTIONS                                #
#######################################################################

###
# Print the usage help
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   None
###
function _extension_usage() {
    echo "$0 [-n | --name] [-p | --package] [-f | --format ] [ -t | --type]

    - -n|--name: Extension's name
    - -p|--packages: List of packages to install into the extension
    - -f|--format: Extension format [ext4, btrfs]
    - -t|--type: Type of the extension [dir, raw]
    - -u|--uki: Path to the referenced UKI [installed one by default]
    - -a|--arch: Specify an architecture
                See https://uapi-group.org/specifications/specs/extension_image/
                For the list of potential value.
    - help: Print this helper

Generate an extension for an UKI 'name-ext.format'
example:
    $0 extension -n \"debug\" -p \"strace,gdb\" -f \"ext4\" -t \"raw\""
}

###
# Provide the optimal partition size according the filesystem size (in MB) 
# Following this calcul: [Partition Size] = [Capacity] / (1 - (inode_size /
#                         inode_ratio) - reserved-blocks-percentage)
# ARGUMENTS:
#   1 - fs size (MB)
# OUTPUTS:
#   partition size (MB)
# RETURN:
#   none
###
function _extension_size_partition() {
    fs_size=$1
    # blocksize=$(head -n 7 /etc/mke2fs.conf\
    #     | grep "blocksize" | awk -F' = ' '{print $2}')
    inode_size=$(head -n 7 /etc/mke2fs.conf\
        | grep "inode_size" | awk -F' = ' '{print $2}')
    inode_ratio=$(head -n 7 /etc/mke2fs.conf\
        | grep "inode_ratio" | awk -F' = ' '{print $2}')
    echo "$((fs_size*1000/(1000-(inode_size*1000)/(inode_ratio*1000)-50)))"
}

###
# Create an initrd extension image
# ARGUMENTS:
#   1 - Extension's name
#   2 - Extension's packages list
#   3 - Extension's format
#   4 - Extension's type
#   5 - Extension's UKI
#   6 - Extension's arch
# OUTPUTS:
#   debug status
# RETURN:
#   0 in success, 1 otherwise
###
function _extension_create() {
    if [ $# -lt 6 ]; then
        echo_debug "Missing arguments"
        return 1
    fi
    local name="${1}"
    local img_name="${name}-ext.raw"
    local pkgs="$2"
    local format="$3"
    local type="$4"
    local uki="$5"
    local arch="$6"
    local tmp_dir
    # local file_dir
    local sized
    local pkg_list
    echo_info "Create the extension '$img_name' with '$pkgs' in format $format\
 at type $type for the uki $uki"
    IFS=',' read -r -a pkg_list <<< "$pkgs"

    # Check if all packages requires are installed
    for pkg in "${pkg_list[@]}"; do
        if ! rpm -q "$pkg" > /dev/null 2>&1; then
            echo_error "'$pkg' is not installed"
            exit 1
        fi
    done

    # Get dependencies of packages
    echo_info "Get all dependencies to install..."
    EXTENSION_LIST_DEPS+=("${pkg_list[@]}")
    for pkg in "${pkg_list[@]}"; do
        _extension_deps_packages "$pkg"
    done
    
    # Get list of files to install
    tmp_dir=$(mktemp -d)
    for pkg in "${EXTENSION_LIST_DEPS[@]}"; do
        list+=" $(rpm -ql "$pkg")"
    done

    # Copy all necessary files
    echo_info "Install all needed files not included yet from the uki ($uki)..."
    for file in $list; do
        if [[ -f $file ]]; then
            if [[ "${EXTENSION_LSINITRD[*]}" =~ ${file:1} ]]; then
                echo_debug "$file already installed"
            else
                cp --parents "$file" "$tmp_dir"
            fi
        fi
    done
    local ext_name="${img_name%.*}"
    local ext_dir=$tmp_dir/usr/lib/extension-release.d
    local ext_file=$ext_dir/extension-release.$ext_name
    mkdir -p "$ext_dir"
    touch "$ext_file"
    id_arg=$(echo "$EXTENSION_INITRD_RELEASE" | grep "^ID=\"*\"")
    ver_id_arg=$(echo "$EXTENSION_INITRD_RELEASE" | grep "^VERSION_ID=\"*\"")
    {
        echo "SYSEXT_LEVEL=2"
        echo "$id_arg"
        echo "$ver_id_arg"
        echo "SYSEXT_ID=$name"
        echo "SYSEXT_SCOPE=initrd"
        # scope=[initrd,system,portable]
        echo "ARCHITECTURE=$arch"
    } > "$ext_file"

    # Create an empty disk raw image extensions
    sized=$(du -s --block-size=1M "$tmp_dir" | awk '{print $1}')
    sized=$((sized+1)) # Add at minimum 1M
    part_sized=$(_extension_size_partition ${sized})
    echo_info "Create an image of sized ${part_sized}M..."
    dd if=/dev/zero of="./$img_name" bs=1M count="$part_sized"  &> /dev/null
    mkfs.ext4 \
        -U "$EXTENSION_PART_UUID" \
        -L "$EXTENSION_PART_LABEL" \
        -d "$tmp_dir" \
        -q \
        "./$img_name"

    # Clean
    [[ "$tmp_dir" ]] && rm -r "$tmp_dir"
    echo_info "extension image created at ./$img_name"
    return 0
}

#######################################################################
#                           ENTRY POINT                               #
#######################################################################

###
# Print the command help
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   NONE
###
function extension_helper() {
    _extension_usage
}

###
# Execute the command
# OUTPUTS:
#   None
# RETURN:
#   0 in success, >0 otherwise
###
function extension_exec() {
    local args
    [[ $# -lt 1 ]] \
        && echo_error "Missing arguments"\
        && _extension_usage && exit 2
    args=$(getopt -a -n extension -o n:p:f:t:u:a:\
        --long name:,packages:,format:,type:,uki:,arch: -- "$@")
    eval set --"$args"
    while :
    do
        case "$1" in
            -n | --name)        local name="$2"     ; shift 2 ;;
            -p | --packages)    local packages="$2" ; shift 2 ;;
            -t | --type)        local type="$2"     ; shift 2 ;;
            -f | --format)      local format="$2"   ; shift 2 ;;
            -u | --uki)         local uki="$2"      ; shift 2 ;;
            -a | --arch)        local arch="$2"     ; shift 2 ;;
            --)                 shift               ; break   ;;
            *)                  echo_warning "Unexpected option: $1"; usage   ;;
        esac
    done
    if [ "$packages" == "" ]; then
        echo_error "Missing packages to install in the extension"
        _extension_usage
        exit 2
    fi
    if [ "$uki" == "" ]; then
        uki=$(ls /usr/lib64/unified/efi/vmlinuz-uki*.efi)
        if [ "$uki" == "" ]; then
            echo_error "No UKI installed, please provides one"
            exit 2
        fi
    else
        if [ ! -f "$uki" ]; then
            echo_error "Cannot find the UKI at $uki"
            exit 2
        fi
    fi
    echo_info "Check the uki $uki..."
    objcopy --dump-section .initrd=initrd-tmp "$uki"
    EXTENSION_LSINITRD=$(lsinitrd ./initrd-tmp | grep " usr/")
    EXTENSION_INITRD_RELEASE=$(lsinitrd -f usr/lib/initrd-release ./initrd-tmp)
    rm initrd-tmp
    if [ "$arch" == "" ]; then
        arch=$(uname -m)
        arch="${arch/_/-}"
    fi
    [[ "$type" == "" ]] && local type="$EXTENSION_TYPE_DEFAULT"
    [[ "$format" == "" ]] && local format="$EXTENSION_FORMAT_DEFAULT"
    _extension_create "$name" "$packages" "$format" "$type" "$uki" "$arch"
    exit $?
}