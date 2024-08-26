#!/bin/sh

# This is the common script that regroups usefull script methods.
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

COMMON_ESP_PATH="/boot/efi"
export COMMON_EFI_PATH="EFI/Linux"
export COMMON_CMDLINE_DEFAULT="splash=silent mitigations=auto quiet"

###
# Check if the system use EFI
# OUTPUTS:
#   NONE
# RETURN:
#   0 if yes, 1 otherwise
###
common_is_efi_system() {
    [ -d "${COMMON_ESP_PATH}" ]
}

###
# Get the device name from the mounted directory
# ARGUMENTS:
#   1 - Directory mounted (/ or /boot/efi)
# OUTPUTS:
#   UUID part
# RETURN:
#   none
###
common_get_dev_name() {
    df -h "$1" | tail -1 | cut -d ' ' -f1
}

###
# Get the UUID partition of a directory mounted
# ARGUMENTS:
#   1 - Device (Call common_get_dev_name)
# OUTPUTS:
#   UUID part
# RETURN:
#   none
###
common_get_dev_uuid() {
    blkid "$1" | sed -e 's|.* UUID="\(.*\)|\1|' | sed 's|" .*||'
}

###
# Get the Available space of a partition
# ARGUMENTS:
#   1 - Device (Call common_get_dev_name)
# OUTPUTS:
#   Available space
# RETURN:
#   none
###
common_get_dev_avail() {
    df --block-size="1M" --output="avail" "$1" | tail -1 | tr -d ' '
}

###
# Get the machine id into machine_id variable
# ARGUMENTS:
#   none
# OUTPUTS:
#   status
# RETURN:
#   none
###
common_get_machine_id() {
    if [ -f /etc/machine-id ]; then
        read -r machine_id < /etc/machine-id
    else
        echo_error "Couldn't determine machine-id"
    fi
}

###
# Verify if the efi parititon has enough space left to install the file
# ARGUMENTS
#   1 - file path
# OUTPUTS:
#   Status
# RETURN:
#   return 0 or failure
###
common_verify_efi_size() {
    if [ ! -f "$1" ]; then
        echo_warning "Verifying an unknow file ($1)"
        return 1
    fi
    efi_dev="$(common_get_dev_name ${COMMON_ESP_PATH})"
    file_size="$(du -m0 "$1" | cut -f 1)"
    efi_avail="$(common_get_dev_avail "$efi_dev")"
    echo_debug "${efi_avail}M available on efi partition"
    echo_debug "Size of $1: ${file_size}M"
    if [ "$file_size" -gt "$efi_avail" ]; then
        echo_error "No space left on efi partition to install $1"
        echo_error "Need ${file_size}M, Available: ${efi_avail}M"
        return 1
    fi
    return 0
}

###
# Install file from src to dst and unchanged if same file
# ARGUMENTS
#   1 - src path
#   2 - dst version
# OUTPUTS:
#   Status
# RETURN:
#   return 0 or failure
###
common_install_file() {
    src_path="$1"
    dst_path="$2"
    if [ ! -f "${src_path}" ]; then
        echo_error "Unknow source ${src_path}"
        return 1
    fi
    if [ -e "${dst_path}" ]; then
        if cmp -s "${src_path}" "${dst_path}"; then
            echo_debug "${dst_path} unchanged"
            return 0
        fi
    fi
    install -p -m 0644 "${src_path}" "${dst_path}" || return "$?"
    chown root:root "${dst_path}" 2>/dev/null || :
    echo_info "${dst_path} installed"
}

###
# If not, install the uki in the efi boot partition
# ARGUMENTS
#   1 - uki path
#   2 - efi dir
# OUTPUTS:
#   Status
# RETURN:
#   exit 2 in failure
###
common_install_uki_in_efi() {
    uki_path="$1"
    image=$(basename "$1")
    efi_d="$2"
    esp_efi_d="${COMMON_ESP_PATH}/${efi_d}"
    # uki_path="/usr/lib/modules/${kerver}/${image}"
    [ ! -d "${esp_efi_d}" ] && mkdir -p "${esp_efi_d}"
    if [ ! -f "${esp_efi_d}/${image}" ]; then
        if [ ! -f "${uki_path}" ]; then
            echo_error "Unable to find the UKI file: ${uki_path}"
            exit 2
        else
            echo_debug "Install UKI in ${esp_efi_d}/${image}"
            common_verify_efi_size "$uki_path" || exit 2
            # efi_dev="$(common_get_dev_name ${COMMON_ESP_PATH})"
            # uki_size="$(du -m0 "$uki_path" | cut -f 1)"
            # efi_avail="$(common_get_dev_avail "$efi_dev")"
            # echo_debug "${efi_avail}M available on efi partition"
            # echo_debug "Size of uki file: ${uki_size}M"
            # if [ "$uki_size" -gt "$efi_avail" ]; then
            #     echo_error "No space left on efi partition to install uki"
            #     echo_error "Need ${uki_size}M, Available: ${efi_avail}M"
            #     exit 2
            # fi
            common_install_file "$uki_path" "${esp_efi_d}/${image}" || {
                echo_error "Error when installing ${esp_efi_d}/${image}"
                exit 2
            }
            # if ! cp "$uki_path" "${esp_efi_d}/${image}"; then
            #     echo_error "Error when installing ${esp_efi_d}/${image}"
            #     exit 2
            # fi
        fi
    fi
}

###
# If not, install the static initrd with the kenerl version into efi dir
# following this pattern: /<boot>/<machineID>/<ker_ver>/{static-initrd, linux}
# If linux file not present, install the linux wollowing the kernel version
# ARGUMENTS
#   1 - initrd path
#   2 - kernel version
# OUTPUTS:
#   Status
# RETURN:
#   exit 2 in failure
###
common_install_initrd_in_efi() {
    initrd_path="$1"
    ker_ver="$2"
    common_get_machine_id
    [ ! ${machine_id+x} ] && exit 2
    esp_machine_d="${COMMON_ESP_PATH}/${machine_id}"
    [ ! -d "${esp_machine_d}" ] && mkdir -p "${esp_machine_d}"
    esp_uname_d="${esp_machine_d}/${ker_ver}"
    [ ! -d "${esp_uname_d}" ] && mkdir -p "${esp_uname_d}"
    linux_file="$(find "${esp_uname_d}" -name "linux*")"
    if [ "${linux_file}" = "" ]; then
        # Copy the kernel
        linux_file="/usr/lib/modules/${ker_ver}/${KER_NAME}"
        common_verify_efi_size "${linux_file}" || exit 2
        common_install_file \
            "${linux_file}" \
            "${esp_uname_d}/linux" || {
            echo_error "Error when installing ${esp_uname_d}/linux"
            exit 2
        }
    fi
    common_verify_efi_size "${initrd_path}" || exit 2
    common_install_file "${initrd_path}" "${esp_uname_d}/static-initrd" || {
        echo_error "Error when installing ${esp_uname_d}/static-initrd"
        exit 2
    }
}