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

SDBOOT_CMD_ADD=1
SDBOOT_CMD_REMOVE=2
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
# Add uki sd-boot entry by creating loader conf file
# ARGUMENTS:
#   1 - uki path
#   2 - efi dir
#   3 - arch
#   4 - kernel version
#   5 - default option
# OUTPUTS:
#   Debug info
###
_sdboot_uki_add_entry() {
    uki="$1"
    efi_d="$2"
    arch="$3"
    kerver="$4"
    default="$5"
    common_install_uki_in_efi "$uki" "$efi_d"

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
# Add initrd sd-boot entry by creating loader conf file
# ARGUMENTS:
#   1 - initrd path
#   2 - efi dir
#   4 - kernel version
#   5 - default option
# OUTPUTS:
#   Debug info
###
_sdboot_initrd_add_entry() {
    initrd_path="$1"
    efi_d="$2"
    kerver="$3"
    default="$4"
    root_dev="$(common_get_dev_name /)"
    root_uuid="$(common_get_dev_uuid "$root_dev")"
    initrd_file=$(basename "${initrd_path}")

    common_install_initrd_in_efi "${initrd_path}" "${kerver}"
    common_get_machine_id
    [ ! ${machine_id+x} ] && exit 2
    esp_uname_d="${COMMON_ESP_PATH}/${machine_id}/${kerver}"
    linux_file=$(find "${esp_uname_d}" -name "linux*")
    linux_file=$(basename "${linux_file}")

    cat > "${SDBOOT_LOADER_ENTRIES_D}/static-${machine_id}-${kerver}.conf" <<EOF
title         Linux ${kerver}, static initrd ${initrd_file}
sort-key      static-initrd
version       ${kerver}
machine-id    ${machine_id}
options       root=UUID=${root_uuid} splash=silent mitigations=auto quiet \
security=apparmor systemd.machine_id=${machine_id}
linux         /${machine_id}/${kerver}/${linux_file}
initrd        /${machine_id}/${kerver}/static-initrd
EOF
    echo_debug "initrd sdboot entry has been added."
    if [ "${default}" = "1" ]; then
        _sdboot_set_default "static-${machine_id}-${kerver}.conf"
    fi
}

###
# Remove the entry conf file of uki
# ARGUMENTS:
#   1 - uki path
#   2 - kernel version
# OUTPUTS:
#   Debug info
# RETURN:
#   exit 2 in error
###
_sdboot_uki_remove_entry() {
    uki="$1"
    kerver="$2"

    uki_file=$(basename "${uki}")
    uki_name=$(basename "${uki}" .efi)
    conf_file="${SDBOOT_LOADER_ENTRIES_D}/${uki_name}_k${kerver}.conf"
    if [ -f "${conf_file}" ]; then
        rm "${conf_file}"
        echo_debug "UKI sdboot entry has been removed..."
    else
        echo_debug "No ${conf_file} to remove."
    fi
}

###
# Remove the entry conf file of initrd
# ARGUMENTS:
#   1 - kernel version
# OUTPUTS:
#   Debug info
# RETURN:
#   exit 2 in error
###
_sdboot_initrd_remove_entry() {
    kerver="$1"
    common_get_machine_id
    [ ! ${machine_id+x} ] && exit 2
    conf_file="${SDBOOT_LOADER_ENTRIES_D}/static-${machine_id}-${kerver}.conf"
    if [ -f "${conf_file}" ]; then
        rm "${conf_file}"
        echo_debug "static initrd sdboot entry has been removed..."
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
  --add | --remove:     Add / Remove sdboot entry (mandatory)
  -k|--kerver:          Kernel Version [Default: $KER_VER]
  -i|--initrd:          Path to the initrd
  -u|--uki:             Path to the UKI name (should be end by .efi)
  -a|--arch:            Architecture to use [Default 'uname -m']
  -e|--efi:             efi directory [Default $COMMON_EFI_PATH]
  -D|--default:         set entry as default (only with --add)
  help:                 Print this helper
 
INFO:
  Create or remove a sdboot entry for the specified UKI or initrd.
  If uki from path (--uki) point to a binary outside the boot partition, it \
will try to install it into ${COMMON_ESP_PATH}/$efi_d.
  If uki just mention an uki name file, it will search the binary from \
'/usr/lib/modules/\$ker_ver/\$image'.
  If the initrd provided isn't in the boot partition, it will copy it in \
/boot 
 
EXAMPLE:
  $BIN sdboot --add -k $(uname -r) -efi /EFI/opensuse -u uki-0.1.0.efi
  $BIN sdboot --remove -k $(uname -r) -u uki-0.1.0.efi"
  printf "%s\n" "$usage_str"
}

###
# Add or Remove UKI menue entry to grsdbootub2
# ARGUMENTS:
#   1 - commands [ADD/REMOVE]
#   2 - kernel version
#   3 - uki path
#   4 - efi dir
#   5 - arch
#   6 - default option
# RETURN:
#   None
###
_sdboot_uki() {
    # uki="$2"
    # kerver="$3"
    # efi_d="$4"
    # arch="$5"
    # default="$6"
    if [ "$cmd" = "$SDBOOT_CMD_ADD" ]; then
        _sdboot_uki_add_entry \
            "${uki}" "${efi_d}" "${arch}" "${kerver}" "${default}"
    else
        _sdboot_uki_remove_entry "${uki}" "${kerver}"
    fi
}

_sdboot_initrd() {
    if [ "$cmd" = "$SDBOOT_CMD_ADD" ]; then
        _sdboot_initrd_add_entry "${initrd}" "${efi_d}" "${kerver}" "${default}"
    else
        _sdboot_initrd_remove_entry "${kerver}"
    fi
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
    args=$(getopt -a -n extension -o u:,i:,k:,a:,e:,D\
        --long add,remove,kerver:,initrd:,uki:,arch:,efi:,default -- "$@")
    eval set --"$args"
    # Init some variables
    kerver="$KER_VER"
    arch=$(uname -m)
    default=0
    while :
    do
        case "$1" in
            --add)              cmd_add=1       ; shift 1 ;;
            --remove)           cmd_remove=1    ; shift 1 ;;
            -k | --kerver)      kerver="$2"     ; shift 2 ;;
            -i | --initrd)      initrd="$2"     ; shift 2 ;;
            -u | --uki)         uki="$2"        ; shift 2 ;;
            -a | --arch)        arch="$2"       ; shift 2 ;;
            -e | --efi)         efi_d="$2"      ; shift 2 ;;
            -D | --default)     default=1       ; shift 1 ;;
            --)                 shift           ; break   ;;
            *) echo_warning "Unexpected option: $1"; _sdboot_usage   ;;
        esac
    done
    case "$arch" in
        aarch64) arch=aa64 ;;
        x86_64)  arch=x64 ;;
        # TODO: add more verification about possibles architecture
    esac
    if [ ! ${initrd+x} ] && [ ! ${uki+x} ]; then
        echo_error "Missing uki or initrd name (--uki|--initrd)"
        exit 2
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
        cmd=$SDBOOT_CMD_ADD
    else
        cmd=$SDBOOT_CMD_REMOVE
    fi
    # Check the mode
    if [ ${initrd+x} ] && [ ${uki+x} ]; then
        echo_error "Please choose between initrd or uki arguments. Not both!"
        _sdboot_usage
        exit 2
    elif [ ! ${initrd+x} ] && [ ! ${uki+x} ]; then
        echo_error "Missing initrd path OR uki path to add to the menu entry"
        _sdboot_usage
        exit 2
    elif [ ${uki+x} ]; then
        if [ ! -f "${uki}" ]; then
            uki_file=$(basename "${uki}")
            uki="/usr/lib/modules/${kerver}/${uki_file}"
        fi
        _sdboot_uki
    elif [ ${initrd+x} ]; then
        if [ ! -f "${initrd}" ]; then
            initrd_file=$(basename "${initrd}")
            initrd="/usr/share/initrd/${initrd_file}"
        fi
        _sdboot_initrd
    fi

}
