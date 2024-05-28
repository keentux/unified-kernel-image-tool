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

COMMON_EFI_FILE="/sys/firmware/efi"

###
# Check if the system use EFI
# OUTPUTS:
#   NONE
# RETURN:
#   0 if yes, 1 otherwise
###
common_is_efi_system() {
    [ -d "${COMMON_EFI_FILE}" ]
}
