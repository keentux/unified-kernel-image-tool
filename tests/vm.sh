#!/bin/sh

# This is the vm script of the uki tool testsuite.
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

VM_NAME="default-vm-name"
VM_LOG_FILE="machine-test.log"
VM_LOG_PATH=""
VM_CURSOR_LINE_LOG=0
# Timeout when connecting to the machine in seconds
VM_TIMEOUT=15
VM_BOOTED_CHECK="(automatic login)"

#######################################################################
#                       MAIN FUNCTIONS                                #
#######################################################################

###
# Setting up the VM env and usefull variables
# ARGUMENTS:
#   1 - source directory (absolute path)
#   2 - test dir
# OUTPUTS:
#   None
# RETURN:
#   None
###
vm_setup() {
    src_dir="$1"
    test_dir="$2"
    cp -r "${src_dir}/tests/mkosi"/* "${test_dir}"/
    # Tips to get sources into the build
    ln -s "${src_dir}" "${test_dir}/mkosi.skeleton"
}

###
# Build a VM using mkosi and its configuration files
# OUTPUTS:
#   Status
# RETURN:
#   0 in success, >0 otherwise
###
vm_build() {
    rc=0
    assert_info "Building the VM ..."
    if ! mkosi --force build; then
        rc=1
        assert_error "VM Failed to build"
    else
        assert_info "VM built !"
    fi
    mkosi genkey
    return ${rc}
}

###
# Wait until the VM is booted or until the trigger of the timeout
# OUTPUTS:
#   Status
# Return:
#   0 if booted, 1 if timeout
###
vm_wait_boot() {
    rc=0
    start=$(date +%s)
    assert_info "Wait ${VM_NAME} to be ready (timeout $VM_TIMEOUT seconds)"

    if [ ! -f "${VM_LOG_PATH}" ]; then
        assert_error "INTERNAL ERROR: Missing log file at ${VM_LOG_PATH}."
        rc=1
    fi

    while [ ${rc} -eq 0 ]; do
        now=$(date +%s)
        elapsed=$((now - start))
        if [ "${elapsed}" -ge "${VM_TIMEOUT}" ]; then
            assert_error "Reaching Timeout ..."
            rc=1
            break
        fi
        # Read new lines from the log file
        if tail -n+$((VM_CURSOR_LINE_LOG + 1)) "${VM_LOG_PATH}" \
            | grep -q "${VM_BOOTED_CHECK}"; then
            VM_CURSOR_LINE_LOG=$(wc -l < "${VM_LOG_PATH}" | awk '{print $1}')
            assert_info "${VM_NAME} is ready"
            break
        fi
    done
    return ${rc}
}

###
# Boot a VM and check if it is ready waiting a timeout in case of failure
# ARGUMENTS:
#   1 - test dir (absolute path)
# OUTPUTS:
#   Status
# RETURN:
#   0 in success, >0 otherwise
###
vm_start() {
    test_d="$1"
    rc=0
    config_f="${test_d}/mkosi.conf"
    
    if [ -f "${config_f}" ]; then
        VM_NAME="$(grep "^Machine=" "${config_f}" | awk -F"=" '{print $2}')"
    else
        assert_error "Missing mkosi config file from ${test_d}"
        assert_error "Please use a test dir where a machine has been config"
        return 1
    fi

    VM_LOG_PATH="${test_d}/${VM_LOG_FILE}"
    touch "${VM_LOG_PATH}"
    
    assert_info "Starting VM: ${VM_NAME}..."
    mkosi --machine="${VM_NAME}" vm > "${VM_LOG_PATH}" 2>&1 &
    MKOSI_PID=$!
    if ! vm_wait_boot; then
        vm_kill
        rc=1
    fi
    return ${rc}
}

###
# Exec a command in a booted VM
# OUTPUTS:
#   Command status
# RETURN:
#   0 id command success, >0 otherwise
###
vm_run_cmd() {
    escaped_args=""
    for arg in "$@"; do
        # Escape all double quotes in arguments
        escaped_arg=$(printf '%s\n' "$arg" | tr '"' '\"')
        escaped_args="$escaped_args \"$escaped_arg\""
    done
    mkosi --machine="${VM_NAME}" ssh -- "${escaped_args}"
}

###
# Update a value of the default conf for the grub bootloader in the created VM
# ARGUMENTS:
#   1 - Key
#   2 - Value
# OUTOUTS:
#   Status
# RETURN:
#   0 in success, >0 otherwise
###
vm_grub_update_default_conf() {
    rc=0
    config_file="/etc/default/grub"
    key="$1"
    value="$2"
    if [ ! ${key+x} ] || [ ! ${value+x} ]; then
        assert_error "INTERNAL ERROR, missing key/value for grub conf."
        rc=1
    fi
    if [ ${rc} -eq 0 ] && [ ! -f "${config_file}" ]; then
        assert_error "${config_file} not found in the VM."
        rc=1
    else
        if vm_run_cmd grep -q "^$key=" "$config_file"; then
            vm_run_cmd sed -i "s|^$key=.*|$key=$value|" "$config_file"
        else
            assert_error "unknown key \"${key}\" from ${config_file}."
            rc=1
        fi
    fi
    return ${rc}
}

###
# Reboot and wait the VM to be ready
# OUTPUTS:
#   Status
# RETURN:
#   0 in success, >0 otherwise
###
vm_reboot() {
    rc=1;
    assert_info "Rebooting the VM ${VM_NAME} ..."
    if vm_run_cmd "reboot"; then
        if ! vm_wait_boot; then
            vm_kill
        else
            rc=0
            assert_info "VM rebooted successfully!"
        fi
    elif [ ${MKOSI_PID+x} ]; then 
        assert_error "Faield to reboot the machine, kill the process..."
        vm_kill
    else
        assert_error "Failed to reboot the VM"
    fi
    return ${rc}
}

###
# Stop a booted VM by sending poweroff. If it fails, it fkills the PID
# OUTPUTS:
#   Status
# RETURN:
#   None
###
vm_stop() {
    assert_info "Stoping the VM: ${VM_NAME} ..."
    if vm_run_cmd "poweroff"; then
        assert_info "VM shutdown successfully!"
    elif [ ${MKOSI_PID+x} ]; then
        assert_error "Faield to power off the machine, kill the process..."
        vm_kill
    else
        assert_error "Failed to stop the VM"
    fi
}

###
# Kill the VM. Needed if the VM is stucked
# OUTPUTS:
#   Status
# RETURN:
#   None
###
vm_kill() {
    assert_info "Killing the VM ${VM_NAME}!"
    if ps -p "${MKOSI_PID}" > /dev/null; then
        assert_info "Killing main mkosi process: $pid"
        kill "${MKOSI_PID}"
    fi
    # Kill all processes related to the createed VM
    if [ ${VM_NAME+x} ]; then
        pids=$(pgrep -f "mkosi.*${VM_NAME}")
        for pid in ${pids}; do
            assert_info "Killing process $pid"
            kill "$pid" 2>/dev/null
        done
    fi
}

###
# Clear generated files from the setup
# ARGUMENTS:
#   1 - source directory (absolute path)
#   2 - test dir
# OUTPUTS:
#   None
# RETURN:
#   None
###
vm_clear() {
    src_dir="$1"
    test_dir="$2"

    rm "${test_dir}/image"*
    rm "${test_dir}/mkosi.key"
    rm "${test_dir}/mkosi.crt"
    [ -f "${VM_LOG_PATH}" ] && rm "${VM_LOG_PATH:?}"
    [ -e "${test_dir}/mkosi.skeleton" ] && \
        rm "${test_dir}/mkosi.skeleton"
    for input in "${src_dir}/tests/mkosi"/*; do
        input="$(basename "${input}")"
        rm -r "${test_dir:?}"/"${input:?}"
    done
}