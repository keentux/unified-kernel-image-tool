#!/bin/sh

# This is the main script of the uki tool.
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

TOOLS_NEEDED=""
export KER_NAME=""
export KER_VER=""
export UKIFY="/usr/lib/systemd/ukify"

#######################################################################
#                           UTILS FUNCTION                            #
#######################################################################

###
# Print a warning message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   warning message
###
echo_warning() {
    color="\033[0;33m"
    color_light="\033[1;33m"
    color_none="\033[0m"
    printf "%b[WARNING]%b %s%b\n" "${color}" "${color_light}" "$1" \
"${color_none}"
}

###
# Print a error message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   error message
###
echo_error() {
    color="\033[0;31m"
    color_light="\033[1;31m"
    color_none="\033[0m"
    printf "%b[ERROR]%b %s%b\n" "${color}" "${color_light}" "$1" "${color_none}"
}

###
# Print a info message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   info message
###
echo_info() {
    color="\033[0;32m"
    color_light="\033[1;32m"
    color_none="\033[0m"
    printf "%b[INFO]%b %s%b\n" "${color}" "${color_light}" "$1" "${color_none}"
}

###
# Print a info message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   info message
###
echo_debug() {
    [ "$VERBOSE" -eq 0 ] && return
    color="\033[0;34m"
    color_light="\033[1;34m"
    color_none="\033[0m"
    printf "%b[DEBUG]%b %s%b\n" "${color}" "${color_light}" "$1" "${color_none}"
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
usage() {
    usage_str="USAGE: $BIN [help] [verbose] COMMAND [help | COMMAND OPTION]
OPTIONS:
  - help:               Print this helper
  - verbose:            Print debug information to the output
  - COMMAND help:       Print the helper of the command
  - COMMAND [OPTION]:   Execute the command with additional options.
 
COMMANDS:"
    for cmd in $CMD; do
        usage_str=$(printf "%s\n  - %s" "$usage_str" "$cmd")
    done
    printf "%s\n" "$usage_str"
}

check_tools_needed() {
    for dep in $TOOLS_NEEDED; do
        if ! command -v "$dep" > /dev/null 2>&1; then
            if [ ${missing_deps+x} ]; then
                missing_deps="$missing_deps $dep"
            else
                missing_deps="$dep"
            fi
        fi
    done
    if [ ${missing_deps+x} ]; then
        echo_error "Some tools are missing on your system: $missing_deps"
        exit 1
    fi
}

#######################################################################
#                           ENTRY POINT                               #
#######################################################################

# Get commands
if [ $# -lt 1 ]; then
    echo_error "Missing command"
    usage & exit 2
fi
cmd_in="$1"
if [ "$cmd_in" = "help" ]\
    || [ "$cmd_in" = "--help" ]\
    || [ "$cmd_in" = "-h" ]; then
        usage
        exit 0
elif [ "$cmd_in" = "verbose" ]\
    || [ "$cmd_in" = "-v" ]; then
    VERBOSE=1
    cmd_in="$2"
    shift 1
fi

# Get the kernel name according the arch
case $(uname -m) in
    "x86_64"|"i386"|"i486"|"i586"|"i686")       KER_NAME="vmlinuz";;
    "ppc"|"ppc64"|"ppcle")                      KER_NAME="vmlinux";;
    "s390"|"s390x")                             KER_NAME="image";;
    "arm")                                      KER_NAME="zImage";;
    "aarch64"|"riscv64")                        KER_NAME="Image";;
    *) echo_error "Unknow Arch" && return 1;;
esac
KER_VER="$(uname -r)"
# Check if cmd exists and exec it
found=0;
for cmd in $CMD; do
    if [ "$cmd" = "$cmd_in" ]; then
        found=1
        if [ "$2" = "help" ]\
            || [ "$2" = "--help" ]\
            || [ "$2" = "-h" ]; then
                "${cmd}_helper"
        else
            # Get dependencies of the command and check them
            TOOLS_NEEDED="$("${cmd}_tools_needed")"
            check_tools_needed
            # Exec the command
            "${cmd}_exec" "$@"
        fi
    fi
done
if [ $found -eq 0 ]; then
    echo_error "Unknown command \"$cmd_in\""
    usage & exit 1
fi
exit 0