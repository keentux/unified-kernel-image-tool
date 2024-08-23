#!/bin/sh

# This is the grub2 command script of the uki tool.
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

GRUB2_CMD_ADD=1
GRUB2_CMD_REMOVE=2
GRUB2_CONFIG_INITRD="43_ukit_initrd"
GRUB2_CONFIG_UKI="44_ukit_uki"
GRUB2_CONFIG_FILE="/boot/grub2/grub.cfg"
GRUB2_DEFAULT_FILE="/etc/default/grub"
GRUB2_TRANSACTIONAL_UPDATE=0

#######################################################################
#                           UTILS FUNCTION                            #
#######################################################################

###
# Regenerate the grub.cfg file according transaction update or not
# ARGUMENTS:
#   None
# OUTPUTS:
#   None
# RETURN:
#   None
###
_grub2_grub_cfg() {
    if [ "$GRUB2_TRANSACTIONAL_UPDATE" -eq 1 ]; then
        transactional-update grub.cfg
    else
        grub2-mkconfig -o "$GRUB2_CONFIG_FILE"
    fi
}

###
# Remove a menuentry block from a config file
# ARGUMENTS:
#   1 - grub config path
#   2 - file to search (could be initrd or uki name)
# OUTPUTS:
#   Informations
# RETURN:
#   None
###
_grub2_remove_menuentry() {
    grub_config_path="$1"
    file_path="$2"
    file=$(basename "$file_path")
    if [ -f "$grub_config_path" ]; then
        if grep -q "$file_path" "$grub_config_path"; then
            echo_info "Removing menuentry for $file_path ..."
            # Get the block to remove:
            start_line=$(grep -n "menuentry.*$file'" "$grub_config_path"\
                | cut -d':' -f1 | head -n 1)
            start_line=$((start_line-1))
            end_line=0
            while IFS= read -r line; do
                end_line=$((end_line+1))
                if expr "$line" : "^EOF" > /dev/null; then
                    [ "$end_line" -gt "$start_line" ] && break
                fi
            done < "$grub_config_path"
            echo_debug "sed -i \"${start_line},${end_line}d\" $grub_config_path"
            sed -i "${start_line},${end_line}d" "$grub_config_path"
            _grub2_grub_cfg
        else
            echo_warning "There isn't a menu entry for $file_path"
            return
        fi
    else
        echo_warning "Grub config file not already created."
    fi
}

###
# Set defaul to an entry with this ID
# ARGUMENTS:
#   1 - entry ID
# OUTPUTS:
#   Errors
# RETURN:
#   None
###
_grub2_set_default() {
    if [ ! "${1+x}" ]; then
        echo_error "Missing argument"
        return
    fi
    sed -i \
        "s|^GRUB_DEFAULT=.*|GRUB_DEFAULT=${1}|" \
        "${GRUB2_DEFAULT_FILE}"
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
_grub2_usage() {
    usage_str="USAGE: $BIN grub2 [OPTIONS]
OPTIONS:
  --add|--remove:       Add/Remove grub2 entry (mandatory)
  -k|--kerver:          Kernel Version [Default: $KER_VER]
  -i|--initrd:          Path to the initrd
  -u|--uki:             Path to the UKI
  -e|--efi:             efi directory [Default $COMMON_EFI_PATH]
  -D|--default:         set entry as default (only with --add)
  help:                 Print this helper
 
INFO:
    Create or remove an entry to the grub2 menu. If initrd argurment is \
provided, uki shouldn't, and vice versa.
    If the initrd provided isn't in the boot partition, it will copy it in \
/boot
    If the uki provided isn't in the the efi partition, it will copy it in \
$COMMON_EFI_PATH
    When remove is asked, --uki should point to the installed uki (in /boot \
partition )
 
EXAMPLE:
    $BIN grub2 --add -k 6.3.4-1-default -u /usr/lib/modules/kerver/uki.efi
    $BIN grub2 --remove -u /boot/efi/EFI/Linux/uki.efi"
    printf "%s\n" "$usage_str"
}

###
# Add or Remove an initrd menue entry to grub2
# ARGUMENTS:
#   1 - commands [ADD/REMOVE]
#   2 - Kernel version
#   3 - Initrd path
#   4 - default option
# RETURN:
#   None
###
_grub2_initrd() {
    cmd=$1
    kerver="$2"
    initrd_path="$3"
    default="$4"
    root_dev="$(common_get_dev_name /)"
    root_uuid="$(common_get_dev_uuid "$root_dev")"
    grub_config_path="/etc/grub.d/$GRUB2_CONFIG_INITRD"
    eof="EOF"
    initrd_file=$(basename "$initrd_path")
    echo_debug "UUID root fs: $root_uuid"
    if [ "$cmd" -eq "$GRUB2_CMD_ADD" ]; then
        if [ ! -f "${initrd_path}" ]; then
            echo_error "Initrd not found at ${initrd_path}."
            exit 2
        fi
        if [ ! -f "/boot/$initrd_file" ]; then
            echo_info "$initrd_file isn't in boot partition, copy it to \
/boot/$initrd_file"
            if ! cp "$initrd_path" "/boot/$initrd_file"; then
                echo_error "Error when adding the initrd to the boot partition"
                exit 2
            fi
        fi
        initrd_path="/boot/$initrd_file"
        if [ -f "$grub_config_path" ]; then
            if grep -q "$initrd_path" "$grub_config_path"; then
                echo_warning "There is already a menu entry for $initrd_path"
                return
            fi
        else
            cat > "$grub_config_path" <<EOF
#!/bin/sh
set -e
EOF
            chmod +x "$grub_config_path"
        fi
        echo_info "Add initrd menuentry for $initrd_path ..."
        entry_id=$(basename "${initrd_path}")
        cat >> "$grub_config_path" <<EOF
cat << $eof
menuentry 'Linux ${kerver} and initrd ${initrd_file}' --id ${entry_id} {
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    search --no-floppy --fs-uuid --set=root ${root_uuid}
    echo "Loading Linux ${kerver} ..."
    linux /boot/vmlinuz-${kerver} root=UUID=${root_uuid}
    echo "Loading ${initrd_path}..."
    initrd ${initrd_path}
}
$eof
EOF
        if [ "${default}" = "1" ]; then
            _grub2_set_default "${entry_id}"
        fi
        _grub2_grub_cfg
    elif [ "$cmd" -eq "$GRUB2_CMD_REMOVE" ]; then
        _grub2_remove_menuentry "$grub_config_path" "$initrd_path"
    fi
}

###
# Add or Remove an UKI menue entry to grub2
# ARGUMENTS:
#   1 - commands [ADD/REMOVE]
#   2 - UKI path
#   3 - efi dir
#   4 - default option
# RETURN:
#   None
###
_grub2_uki() {
    cmd=$1
    uki_path="$2"
    efi_d="$3"
    default="$4"
    efi_dev="$(common_get_dev_name "${COMMON_ESP_PATH}")"
    efi_uuid="$(common_get_dev_uuid "$efi_dev")"
    grub_config_path="/etc/grub.d/$GRUB2_CONFIG_UKI"
    uki_file=$(basename "$uki_path")
    efi_uki_path="/${efi_d}/$uki_file"
    eof="EOF"
    echo_debug "UUID boot partition: $efi_uuid"
    if [ "$cmd" -eq "$GRUB2_CMD_ADD" ]; then
        if [ ! -f "${uki_path}" ]; then
            echo_error "Unified Kernel Image not found at ${uki_path}."
            exit 2
        fi
        common_install_uki_in_efi "${uki_path}" "${efi_d}"
        if [ -f "$grub_config_path" ]; then
            if grep -q "${efi_uki_path}" "${grub_config_path}"; then
                echo_warning "There is already a menu entry for ${efi_uki_path}"
                echo_warning "Remove it before adding it"
                return
            fi
        else
            cat > $grub_config_path <<EOF
#!/bin/sh
set -e
EOF
            chmod +x $grub_config_path
        fi
        echo_info "Add UKI menuentry for $efi_uki_path..."
        uki_name_id=$(basename "${efi_uki_path}" .efi)
        cat >> $grub_config_path <<EOF
cat << $eof
menuentry 'Unified Kernel Image ${uki_file}' --id ${uki_name_id} {
    insmod part_gpt
    insmod btrfs
    insmod chain
    search --no-floppy --fs-uuid --set=root ${efi_uuid}
    echo "Loading unified kernel image ${uki_file} ..."
    chainloader ${efi_uki_path}
}
$eof
EOF
        if [ "${default}" = "1" ]; then
            _grub2_set_default "${uki_name_id}"
        fi
        _grub2_grub_cfg
    elif [ "$cmd" -eq "$GRUB2_CMD_REMOVE" ]; then
        _grub2_remove_menuentry "${grub_config_path}" "${efi_uki_path}"
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
grub2_tools_needed() {
    printf "grub2-mkconfig"
}

###
# Print the command help
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   NONE
###
grub2_helper() {
    _grub2_usage
}

###
# Execute the command grub2
# OUTPUTS:
#   None
# RETURN:
#   0 in success, >0 otherwise
###
grub2_exec() {
    [ $# -lt 2 ] \
        && echo_error "Missing arguments"\
        && _extension_usage && exit 2
    args=$(getopt -a -n extension -o k:i:u:e:D\
        --long add,remove,kerver:,initrd:,uki:,efi:,default -- "$@")
    eval set --"$args"
    while :
    do
        case "$1" in
            --add)              cmd_add=1         ; shift 1 ;;
            --remove)           cmd_remove=1      ; shift 1 ;;
            -k | --kerver)      kerver="$2"       ; shift 2 ;;
            -i | --initrd)      initrd_path="$2"  ; shift 2 ;;
            -u | --uki)         uki_path="$2"     ; shift 2 ;;
            -e | --efi)         efi_d="$2"        ; shift 2 ;;
            -D | --default)     default=1           ; shift 1 ;;
            --)                 shift             ; break   ;;
            *) echo_warning "Unexpected option: $1"; _grub2_usage   ;;
        esac
    done
    # Check transactional update system
    if command -v transactional-update; then
        GRUB2_TRANSACTIONAL_UPDATE=1
    fi
    # Check the command
    if [ ! ${cmd_add+x} ] && [ ! ${cmd_remove+x} ]; then
        echo_error "Need \"add\" or \"remove\" command"
        _grub2_usage
        exit 2
    elif [ ${cmd_add+x} ] && [ ${cmd_remove+x} ]; then
        echo_error "Please choose between add or remove a menue entry. Not\
both!"
        _grub2_usage
        exit 2
    elif [ ${cmd_add+x} ]; then
        cmd=$GRUB2_CMD_ADD
    else
        cmd=$GRUB2_CMD_REMOVE
    fi
    if [ ! ${efi_d+x} ]; then
        efi_d="$COMMON_EFI_PATH"
    else
        efi_d="$(echo "${efi_d}" | sed "s|^/||")"
    fi
    # Check the mode
    if [ ${initrd_path+x} ] && [ ${uki_path+x} ]; then
        echo_error "Please choose between initrd or uki arguments. Not both!"
        _grub2_usage
        exit 2
    elif [ ! ${initrd_path+x} ] && [ ! ${uki_path+x} ]; then
        echo_error "Missing initrd path OR uki path to add to the menu entry"
        _grub2_usage
        exit 2
    elif [ ${uki_path+x} ]; then
        # Check if system is EFI
        if ! common_is_efi_system; then
            echo_error "System doesn't contains ESP partition"
            exit 2
        fi
        _grub2_uki ${cmd} "${uki_path}" "${efi_d}" "${default}"
    else
        # Check the kernel version
        if [ ! ${kerver+x} ]; then
            kerver="$KER_VER"
        fi
        if [ ! -f "/boot/vmlinuz-${kerver}" ]; then
            echo_error "Unable to find the Kernel file: /boot/vmlinuz-${kerver}\
, wrong kernel version ?"
            exit 2
           fi
        _grub2_initrd $cmd "$kerver" "$initrd_path" "${default}"
    fi
}