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

#######################################################################
#                           UTILS FUNCTION                            #
#######################################################################

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
    usage_str="USAGE: $BIN sdboot [--add | --remove] [-k | --kerver] \
[-i | --image]
OPTIONS:
  --add:                Add entry
  --remove:             Remove entry
  -k|--kerver:          Kernel Version [Default: $KER_VER]
  -i|--image:           Image name (should be end by .efi)
  help:                 Print this helper
 
INFO:
  Create or remove an entry to the UKI for sdboot installed for a specified \
Kernel version. It will search binary from '/usr/lib/modules/\$ker_ver/\$image'.
 
EXAMPLE:
  $BIN sdboot --add -k 6.3.4-1-default -i uki-0.1.0.efi
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
    printf "bootctl sdbootutil"
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
    args=$(getopt -a -n extension -o i:,k:\
        --long add,remove,kernel:,image: -- "$@")
    eval set --"$args"
    while :
    do
        case "$1" in
            --add)              cmd_add=1           ; shift 1 ;;
            --remove)           cmd_remove=1        ; shift 1 ;;
            -k | --kerver)      kerver="$2"         ; shift 2 ;;
            -i | --image)       image="$2"          ; shift 2 ;;
            --)                 shift               ; break   ;;
            *) echo_warning "Unexpected option: $1"; _sdboot_usage   ;;
        esac
    done
    # Check the kernel version
    if [ ! ${kerver+x} ]; then
        kerver="$KER_VER"
    fi
    if [ ! ${image+x} ]; then
        echo_error "Missing image name (--image)"
        exit 2
    fi
    if [ ! -f "/usr/lib/modules/${kerver}/${image}" ]; then
        echo_error "Unable to find the UKI file: /usr/lib/modules/${kerver}\
/${image}"
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
        echo_info "Add UKI sdboot entry..."
        err=$(sdbootutil --image="$image" add-uki "$kerver" 2>&1)
        ret=$?
    else
        echo_info "Remove UKI sdboot entry..."
        err=$(sdbootutil --image="$image" remove-uki "$kerver" 2>&1)
        ret=$?
    fi
    if [ $ret -ne 0 ]; then
        echo_error "sdbootutil : '$err'"
        exit 2
    fi
}
