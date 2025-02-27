#!/bin/sh

# This is the common test cript that regroups usefull script methods for tests.
#
# Copyright 2024-2025 Valentin LEFEBVRE <valentin.lefebvre@suse.com>
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
#                           PUBLIC FUNCTIONS                          #
#######################################################################

###
# Print succeeded test
# ARGUMENTS:
#   1 - ID/Name of the test
# OUTPUTS:
#   test succeeded message
###
assert_test_OK() {
    color="\033[38;5;22m"
    color_none="\033[0m"
    printf "%b[OK] %s%b\n" "${color}" "$1" "${color_none}"
}

###
# Print failure test
# ARGUMENTS:
#   1 - ID/Name of the test
# OUTPUTS:
#   test failure message
###
assert_test_NOK() {
    color="\033[38;5;88m"
    color_none="\033[0m"
    printf "%b[NOK] %s%b\n" "${color}" "$1" "${color_none}"
}

###
# Print info message for test
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   info message
###
assert_info() {
    color="\033[38;5;8m"
    color_none="\033[0m"
    printf "%b --- %s%b\n" "${color}" "$1" "${color_none}"
}

###
# Print a error message
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   error message
###
assert_error() {
    color="\033[38;5;88m"
    color_none="\033[0m"
    printf "%b%s%b\n" "${color}" "$1" "${color_none}"
}

###
# Run the cmd in the test environment (it could be in a VM)
# ARGUMENTS:
#   1 - command
# OUTPUTS:
#   cmd output
# RETURN:
#   return of the command
####
test_run_cmd() {
    if [ "${TEST_VM}" = "1" ]; then
        vm_run_cmd "$@"
    else
        "$@"
    fi 
}

###
# Run the cmd only if VM is used (usefull when dealing with reboot, bootloader)
# ARGUMENTS:
#   1 - command
# OUTPUTS:
#   cmd output
# RETURN:
#   return of the command
####
test_run_cmd_vm() {
    if [ "${TEST_VM}" = "1" ]; then
        vm_run_cmd "$@"
    else
        assert_info "Not in VM, skipped"
    fi 
}


###
# Test reboot. Will only be executed if VM is used
# ARGUMENTS:
#   None
# OUTPUTS:
#   Status
# RETURN:
#   0 if rebooted
####
test_run_reboot() {
    if [ "${TEST_VM}" = "1" ]; then
        vm_reboot
    else
        assert_info "Skip rebooting, not in VM"
    fi 
}

###
# Get size of a file in bytes
#   1 - file path
# OUTPUTS:
#   None
# RETURN:
#   size
###
test_common_get_size_bytes() {
    test_run_cmd stat -c %s "$1"
}

###
# Extract the SizeOfImage from an EFI file using objdump
# ARGUMENTS:
#   1 - file path
# OUTPUTS:
#   size
###
test_common_get_SizeOfImage() {
    hexa=$(test_run_cmd objdump -x "$1" \
        | awk '/SizeOfImage/ {print $2}'\
        | tr '[:lower:]' '[:upper:]')
    # echo "$((16#${hexa}))"
    echo "ibase=16; ${hexa}" | bc
}

###
# Check if result is the one expected
# ARGUMENT:
#   1 - expected result
#   2 - result to test
#   3 - [optional] info msg
# OUTPUTS:
#   Error
# RETURN:
#   0 if good, > 0 otherwise
###
test_expected_results() {
    if [ "$1" != "$2" ]; then
        info="  "
        if [ $# -ge 3 ]; then
            info="  [$3] "
        fi 
        assert_error "${info}Expected \"$1\", get \"$2\""
        return 1
    else
        return 0
    fi
}