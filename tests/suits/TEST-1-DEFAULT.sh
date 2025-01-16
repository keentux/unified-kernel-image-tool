#!/bin/sh

# This is the test script of the uki-tool's create command.
#
# Copyright 2025 Valentin LEFEBVRE <valentin.lefebvre@suse.com>
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

TEST_INITRD_NAME="initrd-test"
TEST_UKI_NAME="uki-test"
TEST_CREATE_KERNEL_PATH="/usr/lib/modules/${TEST_UNAME}/${TEST_KER_NAME}"
TEST_CREATE_INITRD_PATH="${TEST_DIR}/${TEST_INITRD_NAME}"
TEST_CREATE_UKI_PATH="${TEST_DIR}/${TEST_UKI_NAME}"
TEST_UKI_CMDLINE="rw rhgb quiet splash"

#######################################################################
#                       PRIVATE FUNCTIONS                             #
#######################################################################


###
# Create the initrd using dracut cmd in the test env
# ARGUMENTS:
#  None
# OUTPUTS:
#  None
# RETURN:
#  dracut return
###
_create_initrd() {
    test_run_cmd dracut         \
        --reproducible          \
        --kver "${TEST_UNAME}"  \
        --quiet                 \
        --force                 \
        "${TEST_CREATE_INITRD_PATH}" > /dev/null 2<&1
}

###
# Create the uki with uki-tool
# ARGUMENTS:
#  None
# OUTPUTS:
#  None
# RETURN:
#  uki-tool return
###
_create_uki() {
    test_run_cmd "${UKITOOL_PATH}" create   \
        -k "${TEST_UNAME}"                  \
        -i "${TEST_CREATE_INITRD_PATH}"     \
        -c "${TEST_UKI_CMDLINE}"            \
        -o "${TEST_DIR}"                    \
        -n "${TEST_UKI_NAME}" > /dev/null 2<&1
}

###
# Get the section's text of an efi file
# ARGUMENTS:
#  None
# OUTPUTS:
#  section's text
# RETURN:
#  rc
###
_get_uki_section_text() {
    test_run_cmd ukify inspect "${TEST_CREATE_UKI_PATH}" \
        --section ".$1:text" \
        | awk '/^  text:/ {flag=1; next} /^  [^ ]/ {flag=0} flag {print $0}' \
        | sed 's/^    //'
}

###
# Get the section's size of an efi file
# ARGUMENTS:
#  None
# OUTPUTS:
#  section's size
# RETURN:
#  rc
###
_get_uki_section_size() {
    test_run_cmd ukify inspect "${TEST_CREATE_UKI_PATH}" \
        --section ".$1:text" \
        | awk '/^  size:/ {print $2}'
}

###
# Check if the UKI is well formatted
# ARGUMENTS:
#  None
# OUTPUTS:
#  status
# RETURN:
#  0 if good, >0 otherwise
###
_verify_uki() {
    rc=0
    # Check the initrd size
    test_expected_results \
        "$(test_common_get_size_bytes "${TEST_CREATE_INITRD_PATH}")" \
        "$(_get_uki_section_size initrd)" \
        "Initrd size" || rc=1
    # Check the kernel size
    #   In some version, Cannot directly verify the size of Kernel size:
    #   Discussed here: https://github.com/systemd/systemd/issues/35851
    #   If this case Ukify used VirtualSize instead of SizeOfRawData. We would 
    #   need to call test_common_get_SizeOfImage instead of
    #   test_common_get_size_bytes.
    test_expected_results \
        "$(test_common_get_size_bytes "${TEST_CREATE_KERNEL_PATH}")" \
        "$(_get_uki_section_size linux)" \
        "Kernel size" || rc=1
    # Check the kernel cmdline
    test_expected_results \
        "${TEST_UKI_CMDLINE}" "$(_get_uki_section_text cmdline)" \
        "Kernel cmdline" || rc=1
    return ${rc}
}

###
# Check if the UKI is bootable, should be run only in VM !
# ARGUMENTS:
#  None
# OUTPUTS:
#  status
# RETURN:
#  0 if good, >0 otherwise
###
_verify_boot() {
    vm_grub_update_default_conf "GRUB_TIMEOUT" "0"
    vm_grub_update_default_conf "GRUB_HIDDEN_TIMEOUT" "0"
    vm_grub_update_default_conf "GRUB_HIDDEN_TIMEOUT_QUIET" "true"
    test_run_cmd_vm "${UKITOOL_PATH}" grub2 --add -u "${TEST_CREATE_UKI_PATH}" \
                -D -t "UKI test"
    test_run_reboot
}

#######################################################################
#                           ENTRY POINT                               #
#######################################################################

###
# Print list of needed tools
# OUTPUTS:
#   list of needed tools
# RETURN:
#   None
###
test_tools_needed() {
    printf "%s" "dracut ukify"
}

###
# Execute the test
# GLOBALS:
#    TEST_DIR: Working directory of the tests
#    UNAME: uname -r
# OUTPUTS:
#   None
# RETURN:
#   0 in success, >0 otherwise
###
test_exec() {
    if ! _create_initrd; then
        assert_error "Failed to create initrd"
        return 1
    fi
    if ! _create_uki; then
        assert_error "Failed to create uki"
        return 1
    fi
    if ! _verify_uki; then
        assert_error "UKI not well generated"
        return 1
    fi
    if [ "${TEST_VM}" = "1" ]; then
        if ! _verify_boot; then
            assert_error "Failed to boot with the UKI"
            return 1
        fi
    fi
    return 0
}
