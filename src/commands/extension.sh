#!/bin/sh

# This is the extension command script for the ukit tool.
#
# Copyright 2024 Valentin LEFEBVRE <valentin.lefebvre@suse.com>
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
EXTENSION_FORMAT_DEFAULT="squashfs"
EXTENSION_PART_UUID="0fc63daf-8483-4772-8e79-3d69d8477de4"
EXTENSION_PART_LABEL="Linux filesystem"
EXTENSION_LIST_DEPS=""
EXTENSION_DEPS=1
# Variable used to optimize extension size
#EXTENSION_LSINITRD=""
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
_extension_deps_packages() {
    pkg="$1"
    found=0
    rpm_cmd=$(rpm -qR "$pkg")
    while read -r require; do
        dep_pkg=$(rpm -q --whatprovides "$require")
        if [ $? -eq 1 ]; then
            continue
        fi
        for elem in $EXTENSION_LIST_DEPS; do
            if [ "$elem" = "$dep_pkg" ]; then
                found=1
                break
            fi
        done
        if [ $found -eq 0 ]; then
            EXTENSION_LIST_DEPS="$EXTENSION_LIST_DEPS $dep_pkg"
            _extension_deps_packages "$dep_pkg"
        else
            found=0
        fi
    done <<rpm_cmd_input
$rpm_cmd
rpm_cmd_input

    # while IFS= read -r require; do
    #     dep_pkg=$(rpm -q --whatprovides "$require")
    #     if [ $? -eq 1 ]; then
    #         continue
    #     fi
    #     for elem in "${EXTENSION_LIST_DEPS[@]}"; do
    #         if [ "$elem" == "$dep_pkg" ]; then
    #             found=1
    #             break
    #         fi
    #     done
    #     if [[ $found -eq 0 ]]; then
    #         EXTENSION_LIST_DEPS+=("$dep_pkg")
    #         _extension_deps_packages "$dep_pkg"
    #     else
    #         found=0
    #     fi
    # done < <(rpm -qR "$pkg")
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
_extension_usage() {
    usage_str="USAGE: $BIN extension [OPTIONS]
OPTIONS:
  -n|--name:            Extension's name
  -p|--packages:        List of packages to install into the extension
  -f|--format:          Extension format (squashfs by default)
  -t|--type:            Type of the extension (dir, raw)
  -u|--uki:             Path to the referenced UKI (installed one by default)
  -a|--arch:            Specify an architecture
                            See https://uapi-group.org/specifications/specs/extension_image
                            For the list of potential value.
  --no-deps:            Build without any dependences
  help:                 Print this helper
 
INFO:
    Generate an extension for an UKI 'name-ext.format'
 
EXAMPLE:
    $BIN extension -n \"debug\" -p \"strace,gdb\" -t \"raw\""
    printf "%s\n" "$usage_str"
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
_extension_size_partition() {
    fs_size=$1
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
_extension_create() {
    if [ $# -lt 6 ]; then
        echo_debug "Missing arguments"
        return 1
    fi
    name="${1}"
    img_name="${name}-ext.raw"
    pkgs="$2"
    format="$3"
    type="$4"
    uki="$5"
    arch="$6"
    echo_info "Create the extension '$img_name' with '$pkgs' in format $format\
 at type $type for the uki $uki"
    for pkg in $(printf "%s" "$pkgs" | sed 's/,/ /g'); do
        if [ "$pkg_list" = "" ]; then
            pkg_list="$pkg";
        else
            pkg_list="$pkg_list $pkg"
        fi
    done

    # Check if all packages requires are installed
    for pkg in $pkg_list; do
        if ! rpm -q "$pkg" > /dev/null 2>&1; then
            echo_error "'$pkg' is not installed"
            exit 1
        fi
    done

    # Get dependencies of packages
    if [ "$EXTENSION_LIST_DEPS" = "" ]; then
        EXTENSION_LIST_DEPS="$pkg_list";
    else
        EXTENSION_LIST_DEPS="$EXTENSION_LIST_DEPS $pkg_list"
    fi
    if [ $EXTENSION_DEPS -eq 1 ]; then 
        echo_info "Get all dependencies to install..."
        for pkg in $pkg_list; do
            _extension_deps_packages "$pkg"
        done
    fi
    
    # Get list of files to install
    tmp_dir=$(mktemp -d)
    for pkg in $EXTENSION_LIST_DEPS; do
        for file in $(rpm -ql "$pkg" | sed 's/\n/ /g'); do
            if [ -f "$file" ]; then
                cp --parents "$file" "$tmp_dir"
            fi
        done
    done
# --- Size Optimization but take too much time to build
#
#     # Get list of files to install
#     tmp_dir=$(mktemp -d)
#     for pkg in $EXTENSION_LIST_DEPS; do
#         pkg_files="$(rpm -ql "$pkg" | sed 's/\n/ /g')"
#         if [ "$list" = "" ]; then
#             list="$pkg_files"
#         else
#             list="$list $pkg_files"
#         fi
#     done
#
#     # Copy all necessary files
#     echo_info "Install all needed files not included yet from the uki ($uki)..."
#     read_lsinitrd=$(printf "%s" "$EXTENSION_LSINITRD")
#
#     for file in $list; do
#         if [ -f "$file" ]; then
#             read_lsinitrd=$(printf "%s" "$EXTENSION_LSINITRD")
#             file_tmp="$(printf "%s" "$file" | cut -d / -f2-)"
#             while read -r line; do
#                 if expr "$line" : "*$file_tmp*" > /dev/null; then
#                     echo_debug "$file already installed"
#                 else
#                     cp --parents "$file" "$tmp_dir"
#                 fi
#             done <<EOF_cmd
# $read_lsinitrd
# EOF_cmd
#         fi
#     done
#
# ---
    ext_name="${img_name%.*}"
    ext_dir=$tmp_dir/usr/lib/extension-release.d
    ext_file=$ext_dir/extension-release.$ext_name
    mkdir -p "$ext_dir"
    touch "$ext_file"
    id_arg=$(echo "$EXTENSION_INITRD_RELEASE" | grep "^ID=\"*\"")
    ver_id_arg=$(echo "$EXTENSION_INITRD_RELEASE" | grep "^VERSION_ID=\"*\"")
    {
        echo "SYSEXT_LEVEL=2"
        echo "$id_arg"
        echo "$ver_id_arg"
        echo "SYSEXT_ID=$name"
        # scope=[initrd,system,portable]
        echo "SYSEXT_SCOPE=initrd"
        echo "ARCHITECTURE=$arch"
    } > "$ext_file"

    # Create an empty disk raw image extensions
    sized=$(du -s --block-size=1M "$tmp_dir" | awk '{print $1}')
    sized=$((sized+1)) # Add at minimum 1M
    part_sized=$(_extension_size_partition ${sized})
    echo_info "Create an image of sized ${part_sized}M..."
    if [ "$format" = "$EXTENSION_FORMAT_DEFAULT" ]; then
        mksquashfs \
            "$tmp_dir" \
            "./$img_name" \
            -quiet
    else
        dd if=/dev/zero of="./$img_name" bs=1M count="$part_sized" \
            > /dev/null 2>&1
        mkfs."$format" \
            -U "$EXTENSION_PART_UUID" \
            -L "$EXTENSION_PART_LABEL" \
            -d "$tmp_dir" \
            -q \
            "./$img_name"
    fi
    # Clean
    [ "$tmp_dir" ] && rm -r "$tmp_dir"
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
extension_helper() {
    _extension_usage
}

###
# Print the list of needed tool for the command
# OUTPUTS:
#   NONE
# RETURN:
#   lsit of needed tools
###
extension_tools_needed() {
    printf "objcopy lsinitrd mksquashfs mktemp"
}

###
# Execute the command
# OUTPUTS:
#   None
# RETURN:
#   0 in success, >0 otherwise
###
extension_exec() {
    [ $# -lt 2 ] \
        && echo_error "Missing arguments"\
        && _extension_usage && exit 2
    args=$(getopt -a -n extension -o n:p:f:t:u:a:\
        --long name:,packages:,format:,type:,uki:,arch:,no-deps -- "$@")
    eval set --"$args"
    while :
    do
        case "$1" in
            -n | --name)        name="$2"           ; shift 2 ;;
            -p | --packages)    packages="$2"       ; shift 2 ;;
            -t | --type)        type="$2"           ; shift 2 ;;
            -f | --format)      format="$2"         ; shift 2 ;;
            -u | --uki)         uki="$2"            ; shift 2 ;;
            -a | --arch)        arch="$2"           ; shift 2 ;;
            --no-deps)          EXTENSION_DEPS=0    ; shift 1 ;;
            --)                 shift               ; break   ;;
            *) echo_warning "Unexpected option: $1"; _extension_usage   ;;
        esac
    done
    if [ ! ${packages+x} ]; then
        echo_error "Missing packages to install in the extension"
        _extension_usage
        exit 2
    fi
    if [ ! ${uki+x} ]; then
        count=0
        for uki_f in /usr/share/unified/efi/uki*.efi; do
            if [ -e "$uki_f" ]; then
                count=$((count +1))
                uki="$uki_f"
            fi
        done
        if [ "$count" -eq 0 ]; then
            echo_error "No UKI installed, please provides one"
            exit 2
        elif [ "$count" -ne 1 ]; then
            echo_error "More tahn one UKI installed, please select one"
            exit 2
        fi
    else
        if [ ! -f "$uki" ]; then
            echo_error "Cannot find the UKI at $uki"
            exit 2
        fi
    fi
    echo_info "Check the uki $uki and extract the initrd..."
    objcopy --dump-section .initrd=initrd-tmp "$uki"
    #EXTENSION_LSINITRD=$(lsinitrd ./initrd-tmp | grep " usr/")
    EXTENSION_INITRD_RELEASE=$(lsinitrd -f usr/lib/initrd-release ./initrd-tmp)
    rm initrd-tmp
    if [ ! ${arch+x} ]; then
        arch=$(printf "%s" "$(uname -m)" | sed 's/_/-/g')
    fi
    [ ! ${type+x} ] && type="$EXTENSION_TYPE_DEFAULT"
    if [ ! ${format+x} ]; then 
        format="$EXTENSION_FORMAT_DEFAULT"
    elif [ ! -f "/usr/sbin/mkfs.$format" ]; then
        echo_error "No mkfs.$format found, use another format"
        exit 1
    fi
    _extension_create "$name" "$packages" "$format" "$type" "$uki" "$arch"
    exit $?
}
