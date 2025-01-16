#!/bin/sh

# This is the test script of the uki tool.
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

export TEST_DIR=""
TEST_DIR="$(realpath ./tests-"$(date  '+%Y-%m-%d_%H:%M:%S')")"
export TEST_UNAME=""
TEST_UNAME="$(uname -r)"
# Get the kernel name according the arch
export TEST_KER_NAME=""
case $(uname -m) in
    "x86_64"|"i386"|"i486"|"i586"|"i686")   TEST_KER_NAME="vmlinuz";;
    "ppc"|"ppc64"|"ppcle")                  TEST_KER_NAME="vmlinux";;
    "s390"|"s390x")                         TEST_KER_NAME="image";;
    "arm")                                  TEST_KER_NAME="zImage";;
    "aarch64"|"riscv64")                    TEST_KER_NAME="Image";;
    *)                                      echo "Unknow Arch" && exit 1;;
esac
IS_TEST_DIR_CREATED=0
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/vm.sh"

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
test_usage() {
    usage_str="USAGE: $0 [OPTIONS]
OPTIONS:
  -u|--unit:        Run specific unit test by this filename
                        If not, run all tests
  -p|--path:        Path to the uki-tool script to test
  -k|--kerver:      Custom kernel version
                        Useful only if vm isn't used
                        [default: (uname -r)]
  -d|--dir:         Use a custom test dir. If tests have already been run
                    inside, the VM creation is skipped.
                        [default: ./tests-<date>]
  -v|--vm:          Use VM to run TESTs
  -c|--clear:       Clear generated test files
  help:             Print this helper
 
INFO:
    Test suite of the uki-tool script"
    printf "%s\n" "$usage_str"
}

###
# Setup the test environment
# Checking dependencies tools and creating the working directory
# ARGUMENTS:
#   1 - message to print
# OUTPUTS:
#   info message
# RETURN:
#   0 if success, >0 otherwise
###
test_setup() {
    rc=0
    pwd=${PWD}

    if ! test -d "${TEST_DIR}"; then
        assert_info "Creating ${TEST_DIR}"
        mkdir "${TEST_DIR}"
        IS_TEST_DIR_CREATED=1
        if [ "${TEST_VM}" = "1" ]; then
            assert_info "Setup VM env ..."
            vm_setup "$(realpath "$(dirname "$0")"/..)" "${TEST_DIR}"
            cd "${TEST_DIR}" || { 
                assert_error "Failed to cd in ${TEST_DIR}"; rc=1;
            }
            if ! vm_build; then
                assert_error "Failed to build vm"
                rc=1
            fi
            cd "$pwd" || { 
                assert_error "Failed to cd in ${pwd}"; rc=1;
            }
        fi
    fi

    if [ ${rc} -eq 0 ] && [ "${TEST_VM}" = "1" ]; then
        cd "${TEST_DIR}" || { 
            assert_error "Failed to cd in ${TEST_DIR}"; rc=1;
        }
        if ! vm_start "${TEST_DIR}"; then
            assert_error "Failed to start vm"
            rc=1
        else
            # Prepare test env in the VM
            test_run_cmd mkdir -p "${TEST_DIR}"
            TEST_UNAME="$(test_run_cmd uname -r)"
        fi
        cd "$pwd" || {
            assert_error "Failed to cd in ${pwd}"; rc=1;
        }
    fi

    return ${rc}
}

###
# Run a specfific unit test
# Check this dependencies before running test_exec function
# ARGUMENTS:
#   1 - filename test
# OUTPUTS:
#   info messages
###
test_run_unit() {
    file="$1"
    testfile=$(basename "${file}" .sh)
    # shellcheck source=/dev/null
    . "${file}"
    TEST_NBR=$((TEST_NBR+1))
    deps=$(test_tools_needed)
    for dep in $deps; do
        if ! test_run_cmd command -v "$dep" > /dev/null 2>&1; then
            if [ ${missing_deps+x} ]; then
                missing_deps="$missing_deps $dep"
            else
                missing_deps="$dep"
            fi
        fi
    done
    if [ ${missing_deps+x} ]; then
        assert_error "Missing tool for test ${testfile}: ${missing_deps}"
        TEST_NBR_FAILED=$((TEST_NBR_FAILED+1))
    else
        if test_exec; then
            assert_test_OK "${testfile}"
        else
            assert_test_NOK "${testfile}"
            TEST_NBR_FAILED=$((TEST_NBR_FAILED+1))
        fi
        if [ "${TEST_CLEAR}" = "1" ]; then
            test_clear
        fi
    fi
}

###
# Close the VM if needed and Clean the test environment
# OUTPUTS:
#   infos
# RETURN:
#   0
###
test_teardown() {
    [ "${TEST_VM}" = "1" ] && vm_stop
    if [ "${TEST_CLEAR}" = "1" ] && [ -d "${TEST_DIR}" ]; then
        if [ ${IS_TEST_DIR_CREATED} -eq 1 ]; then
            assert_info "Removing ${TEST_DIR} ..."
            rm -r "${TEST_DIR}"
        else
            assert_info "Cleaning ${TEST_DIR} ..."
            [ "${TEST_VM}" = "1" ] && \
                vm_clear "$(realpath "$(dirname "$0")"/..)" "${TEST_DIR}"
            [ "$(ls -A "${TEST_DIR}")" = "" ] && rm -r "${TEST_DIR}"
        fi
    fi
}

#######################################################################
#                           ENTRY POINT                               #
#######################################################################

TEST_NBR=0
TEST_NBR_FAILED=0

# Get arguments
args=$(getopt -a -n "$0" -o u:p:k:d:vch\
    --long unit:,path:,kerver:,dir:,clear,vm,help -- "$@")
eval set --"$args"
while :
do
    case "$1" in
        -u | --unit)        TEST_UNIT="$2"      ; shift 2 ;;
        -p | --path)        UKITOOL_PATH="$2"   ; shift 2 ;;
        -k | --kerver)      TEST_UNAME="$2"     ; shift 2 ;;
        -d | --dir)         TEST_DIR="$2"       ; shift 2 ;;
        -c | --clear)       TEST_CLEAR=1        ; shift 1 ;;
        -v | --vm)          TEST_VM=1           ; shift 1 ;;
        -h | --help)        test_usage          ; exit 0  ;;
        --)                 shift               ; break   ;;
        *) assert_error "Unexpected option: $1"; test_usage; exit 0 ;;
    esac
done

if ! test_setup; then
    assert_error "Failed to setup tests."
    exit 1
fi

if [ ! ${UKITOOL_PATH+x} ]; then
    if test_run_cmd command -v uki-tool > /dev/null 2>&1; then
        UKITOOL_PATH=$(test_run_cmd which uki-tool)
    else
        assert_error "Can't find uki-tool from PATH"
        exit 1
    fi
fi
assert_info "Testing ${UKITOOL_PATH}"

test_dir="$(dirname "$0")/suits"
if [ ${TEST_UNIT+x} ]; then
    if test -f "${test_dir}/${TEST_UNIT}.sh"; then
        test_run_unit "${test_dir}/${TEST_UNIT}.sh"
    else
        assert_error "No tests found at ${test_dir}/${TEST_UNIT}.sh"
        TEST_NBR_FAILED=1
    fi
else
    for file in "${test_dir}"/*; do
        test_run_unit "$file"
    done
fi
assert_info "${TEST_NBR} test(s), ${TEST_NBR_FAILED} failure(s)!"

test_teardown

exit $TEST_NBR_FAILED