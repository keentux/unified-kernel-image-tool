#!/bin/bash

# This is the main script of the uki tool.
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
function echo_warning() {
    local color="\033[0;33m"
    local color_light="\033[1;33m"
    local color_none="\033[0m"
    echo -e "${color}[WARNING] ${FUNCNAME[1]} ${color_light}$1${color_none}"
}

###
# Print a error message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   error message
###
function echo_error() {
    local color="\033[0;31m"
    local color_light="\033[1;31m"
    local color_none="\033[0m"
    echo -e "${color}[ERROR] ${FUNCNAME[1]} -- ${color_light}$1${color_none}"
}

###
# Print a info message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   info message
###
function echo_info() {
    local color="\033[0;32m"
    local color_light="\033[1;32m"
    local color_none="\033[0m"
    echo -e "${color}[INFO]\t${color_light}$1${color_none}"
}

###
# Print a info message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   info message
###
function echo_debug() {
    [[ $VERBOSE -eq 0 ]] && return
    local color="\033[0;34m"
    local color_light="\033[1;34m"
    local color_none="\033[0m"
    echo -e "${color}[DEBUG] ${color_light}$1${color_none}"
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
function usage() {
    echo -e "$0 [ help ] COMMAND [ help | COMMAND OPTION ] 

    - help: Print this helper
    - COMMAND help: Print the helper of the command
    - COMMAND [OPTION]: Execute the command with additional options.

\nList of COMMAND:"
    for cmd in $CMD; do
        echo -e "    - $cmd"
    done
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
if [ "$cmd_in" == "help" ]\
    || [ "$cmd_in" == "--help" ]\
    || [ "$cmd_in" == "-h" ]; then
        usage & exit 0
fi
# Check if cmd exists and exec it
found=0;
for cmd in $CMD; do
    if [ "$cmd" == "$cmd_in" ]; then
        found=1
        if [ "$2" == "help" ]\
            || [ "$2" == "--help" ]\
            || [ "$2" == "-h" ]; then
                ${cmd}_helper
        else
            ${cmd}_exec "$@"
        fi
    fi
done
if [ $found -eq 0 ]; then
    echo_error "Unknown command \"$cmd_in\""
    usage & exit 1
fi
exit 0