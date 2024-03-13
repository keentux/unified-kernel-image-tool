#!/bin/sh

# This is the create command script of the uki tool.
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

ADDON_STUB_PATH="/usr/lib/systemd/boot/efi/addonx64.efi.stub"
ADDON_EXTENSION="addon.efi"

#######################################################################
#                       PRIVATE FUNCTIONS                             #
#######################################################################

###
# Print the usage help
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   2
###
_addon_usage() {
    usage_str="USAGE: $BIN addon [OPTIONS]
OPTIONS:
  -c|--cmdline:         To put in .cmdline section
  -n|--name:            Name of the addon
  -o|--output:          Output dir where to generate the addon.
                            [Default: $PWD]
  help:                 Print this helper
 
INFO:
    Generate an addon with a custom .cmdline section using the systemd tool
'ukify'
 
EXAMPLE:
    $BIN addon -c ='|Test uki addon|' -o /boot/efi/EFI/loader/addons -n test"
    printf "%s\n" "$usage_str"
}

### Generate an addon
# ARGUMENTS:
#   1 - output dir
#   2 - cmdline
#   3 - name
# OUTPUTS:
#   Location of the built addon.
# RETURN:
#  0 in succes, >0 otherwise
###
_addon_generate() {
    err=0
    if [ $# -lt 3 ]; then
        echo_error "Missing arguments"
        err=1
    elif [ ! -d "$1" ]; then
        echo_error "No dir at $1"
        err=1
    fi
    if [ $err -ne 1 ]; then
        if $UKIFY build \
            --stub="$ADDON_STUB_PATH" \
            --cmdline="$2" \
            --output="$1/$3"; then
            echo_info "Addon generated: $1/$3"
        else
            echo_error "$UKIFY failed to create the addon at $1/$3"
            err=1
        fi
    fi
    return $err
}

#######################################################################
#                           ENTRY POINT                               #
#######################################################################

###
# Print the helper of the addon command
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   NONE
###
addon_helper() {
    _addon_usage
}

###
# Print the list of needed tool for the command
# OUTPUTS:
#   NONE
# RETURN:
#   lsit of needed tools
###
addon_tools_needed() {
    printf "%s" "$UKIFY"
}

###
# Execute the command addon
# OUTPUTS:
#   None
# RETURN:
#   0 in success, >0 otherwise
###
addon_exec() {
    printf "Execute command addon\n"
    # Get arguments
    args=$(getopt -a -n extension -o n:c:o:\
        --long name:,cmdline:,output: -- "$@")
    eval set --"$args"
    while :
    do
        case "$1" in
            -n | --name)        name="$2"           ; shift 2 ;;
            -c | --cmdline)     cmdline="$2"        ; shift 2 ;;
            -o | --output)      output="$2"         ; shift 2 ;;
            --)                 shift               ; break   ;;
            *) echo_warning "Unexpected option: $1"; _addon_usage   ;;
        esac
    done
    if [ ! ${name+x} ]; then
        echo_error "Missing Name"
        return 1
    fi
    # addon_extension=$(echo "$name" | rev | cut -d '.' -f1-2 | rev)
    if [ "$(echo "$name" | rev | cut -d '.' -f1-2 | rev)" \
      != "$ADDON_EXTENSION" ]; then
        name="${name}.$ADDON_EXTENSION"
    fi
    if [ ! ${cmdline+x} ]; then
        echo_error "Missing cmdline"
        return 1
    fi
    if [ ! ${output+x} ]; then
        output="$PWD"
    fi
    # Generate Addon
    _addon_generate "$output" "$cmdline" "$name"
}
