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

#######################################################################
#                           UTILS FUNCTION                            #
#######################################################################

#######################################################################
#                       MAIN FUNCTIONS                                #
#######################################################################

###
# Print the list of needed tool for the command
# OUTPUTS:
#   NONE
# RETURN:
#   lsit of needed tools
###
create_tools_needed() {
    printf ""
}

###
# Print the usage help
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   2
###
create_usage() {
    printf "Helper of the create command\n"
    exit 2
}

#######################################################################
#                           ENTRY POINT                               #
#######################################################################

create_helper() {
    create_usage
}

create_tools_needed() {
    print ""
}

create_exec() {
    printf "Execute command create\n"
}
