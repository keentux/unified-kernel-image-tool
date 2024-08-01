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
            efi_dev="$(common_get_dev_name ${COMMON_ESP_PATH})"
            uki_size="$(du -m0 "$uki_path" | cut -f 1)"
            efi_avail="$(common_get_dev_avail "$efi_dev")"
            echo_debug "${efi_avail}M available on efi partition"
            echo_debug "Size of uki file: ${uki_size}M"
            if [ "$uki_size" -gt "$efi_avail" ]; then
                echo_error "No space left on efi partition to install uki"
                echo_error "Need ${uki_size}M, Available: ${efi_avail}M"
                exit 2
            fi
            if ! cp "$uki_path" "${esp_efi_d}/${image}"; then
                echo_error "Error when installing ${esp_efi_d}/${image}"
                exit 2
            fi
        fi
    fi
}
