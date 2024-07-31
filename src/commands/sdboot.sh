#!/bin/sh

# This is the sdboot command script of the uki tool.
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

SDBOOT_LOADER_CONF="${COMMON_ESP_PATH}/loader/loader.conf"
SDBOOT_LOADER_ENTRIES_D="${COMMON_ESP_PATH}/loader/entries"
SDBOOT_CONF_DEAFULT_KEY="default"

#######################################################################
#                           UTILS FUNCTION                            #
#######################################################################

###
# Will bootctl install if not the case
###
_sdboot_install_bootctl() {
    if [ "$(bootctl is-installed)" = "no" ]; then
        bootctl install --esp-path="${COMMON_ESP_PATH}"
    fi
}

###
# Set a conf file as default to boot
# ARGUMENTS:
#   1 - conf name
# RETURN:
#   exit 2 in error
###
_sdboot_set_default() {
    conf_name="$1"
    if [ ! -f "${SDBOOT_LOADER_ENTRIES_D}/${conf_name}" ]; then
        echo_error "Failed to set default, No confif file \
${SDBOOT_LOADER_ENTRIES_D}/${conf_name}."
        exit 2
    fi
    if grep -q "^${SDBOOT_CONF_DEAFULT_KEY}" "${SDBOOT_LOADER_CONF}"; then
        sed -i \
"s|^${SDBOOT_CONF_DEAFULT_KEY}.*|${SDBOOT_CONF_DEAFULT_KEY} ${conf_name}|" \
"${SDBOOT_LOADER_CONF}"
    else
        echo "${SDBOOT_CONF_DEAFULT_KEY} ${conf_name}" \
            >> "${SDBOOT_LOADER_CONF}"
    fi

}

###
# Add sd-boot entry by creating loader conf file
# ARGUMENTS:
#   1 - uki path
#   2 - efi dir
#   3 - arch
#   4 - kernel version
#   5 - default option
# OUTPUTS:
#   Debug info
###
_sdboot_add_entry() {
    uki="$1"
    efi_d="$2"
    arch="$3"
    kerver="$4"
    default="$5"
    common_install_uki_in_efi "$uki" "$efi_d"

    case "$arch" in
        aarch64) arch=aa64 ;;
        x86_64)  arch=x64 ;;
        # TODO: add more verification about possibles architecture
    esac

    uki_file=$(basename "${uki}")
    uki_name=$(basename "${uki}" .efi)
    uki_ver=$(echo "$uki_name" | sed -e 's|^uki-||')
    cat > "${SDBOOT_LOADER_ENTRIES_D}/${uki_name}_k${kerver}.conf" <<EOF
title         Unified Kernel Image ${uki_name}
sort-key      UKI
version       ${uki_ver}_k${kerver}
efi           ${efi_d}/${uki_file}
architecture  ${arch}
EOF
    echo_debug "UKI sdboot entry has been added."
    if [ "${default}" = "1" ]; then
        _sdboot_set_default "${uki_name}_k${kerver}.conf"
    fi
}

###
# Remove the entry conf file
# ARGUMENTS:
#   1 - uki path
#   2 - kernel version
# OUTPUTS:
#   Debug info
# RETURN:
#   exit 2 in error
###
_sdboot_remove_entry() {
    uki="$1"
    kerver="$2"

    uki_file=$(basename "${uki}")
    uki_name=$(basename "${uki}" .efi)
    conf_file="${SDBOOT_LOADER_ENTRIES_D}/${uki_name}_k${kerver}"
    if [ -f "${conf_file}" ]; then
        rm "${SDBOOT_LOADER_ENTRIES_D}/${uki_name}_k${kerver}.conf"
        echo_debug "UKI sdboot entry has been removed..."
    else
        echo_debug "No ${conf_file} to remove."
    fi
}

#######################################################################
#                       MAIN FUNCTIONS                                #
#######################################################################

###
# Print the usage help
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   2
###
_sdboot_usage() {
    usage_str="USAGE: $BIN sdboot [OPTIONS]
OPTIONS:
  --add:                Add entry
  --remove:             Remove entry
  -k|--kerver:          Kernel Version [Default: $KER_VER]
  -u|--uki:             Path to the UKI name (should be end by .efi)
  -a|--arch:            Architecture to use [Default 'uname -m']
  -e|--efi:             efi directory [Default $COMMON_EFI_PATH]
  -D|--default:         set entry as default (only with --add)
  help:                 Print this helper
 
INFO:
    Create or remove a sdboot entry for the specified UKI.
    If uki from path (--uki) point to a binary outside the boot partition, it
    will try to install it into ${COMMON_ESP_PATH}/$efi_d.
    If uki just mention an uki name file, it will search the binary from
    '/usr/lib/modules/\$ker_ver/\$image'.
 
EXAMPLE:
  $BIN sdboot --add -k $(uname -r) -efi /EFI/opensuse -u uki-0.1.0.efi
  $BIN sdboot --remove -k $(uname -r) -u uki-0.1.0.efi
"
    printf "%s\n" "$usage_str"
}

#######################################################################
#                           ENTRY POINT                               #
#######################################################################

###
# Print the list of needed tool for the command
# OUTPUTS:
#   NONE
# RETURN:
#   lsit of needed tools
###
sdboot_tools_needed() {
    printf "bootctl"
}

###
# Print the command help
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   NONE
###
sdboot_helper() {
    _sdboot_usage
}

###
# Execute the command sdboot
# OUTPUTS:
#   None
# RETURN:
#   0 in success, >0 otherwise
###
sdboot_exec() {
    [ $# -lt 2 ] \
        && echo_error "Missing arguments"\
        && _extension_usage && exit 2
    args=$(getopt -a -n extension -o u:,k:,a:,e:,D\
        --long add,remove,kernel:,uki:,arch:,efi:,default -- "$@")
    eval set --"$args"
    while :
    do
        case "$1" in
            --add)              cmd_add=1           ; shift 1 ;;
            --remove)           cmd_remove=1        ; shift 1 ;;
            -k | --kerver)      kerver="$2"         ; shift 2 ;;
            -u | --uki)         uki="$2"            ; shift 2 ;;
            -a | --arch)        arch="$2"           ; shift 2 ;;
            -e | --efi)         efi_d="$2"          ; shift 2 ;;
            -D | --default)     default=1           ; shift 1 ;;
            --)                 shift               ; break   ;;
            *) echo_warning "Unexpected option: $1"; _sdboot_usage   ;;
        esac
    done
    if [ ! ${kerver+x} ]; then
        kerver="$KER_VER"
    fi
    if [ ! ${uki+x} ]; then
        echo_error "Missing uki name (--uki)"
        exit 2
    fi
    if [ ! ${arch+x} ]; then
        arch=$(uname -m)
    fi
    if [ ! ${efi_d+x} ]; then
        efi_d="$COMMON_EFI_PATH"
    else
        efi_d="$(echo "${efi_d}" | sed "s|^/||")"
    fi
    # Check if system is EFI
    if ! common_is_efi_system; then
        echo_error "System doesn't contains ESP partition"
        exit 2
    fi
    # Check the command
    if [ ! ${cmd_add+x} ] && [ ! ${cmd_remove+x} ]; then
        echo_error "Need \"add\" or \"remove\" command"
        _sdboot_usage
        exit 2
    elif [ ${cmd_add+x} ] && [ ${cmd_remove+x} ]; then
        echo_error "Please choose between add or remove a menue entry. Not\
both!"
        _sdboot_usage
        exit 2
    elif [ ${cmd_add+x} ]; then
        _sdboot_install_bootctl
        if [ ! -f "${uki}" ]; then
            uki_file=$(basename "${uki}")
            uki="/usr/lib/modules/${kerver}/${uki_file}"
        fi
        _sdboot_add_entry "${uki}" "${efi_d}" "${arch}" "${kerver}" "${default}"
        # err=$(sdbootutil \
        #     --arch="$arch" \
        #     --image="$uki" \
        #     add-uki "$kerver" 2>&1)
        # ret=$?
    else
        _sdboot_remove_entry "${uki}" "${kerver}"
        # err=$(sdbootutil \
        #     --arch="$arch" \
        #     --image="$uki" \
        #     remove-uki "$kerver" \
        #     2>&1)
        # ret=$?
    fi
    # if [ $ret -ne 0 ]; then
    #     echo_error "sdbootutil : '$err'"
    #     exit 2
    # fi
}
