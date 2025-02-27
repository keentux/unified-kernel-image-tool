#!/bin/sh

# This is the create command script of the uki tool.
#
# Copyright 2023-2025 Valentin LEFEBVRE <valentin.lefebvre@suse.com>
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

CREATE_DEFAULT_UKI_NAME="uki"
CREATE_DEFAULT_CMDLINE="rw rhgb"
CREATE_GENKEYS="n"

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
_create_usage() {
    usage_str="USAGE: $BIN create [OPTIONS]
OPTIONS:
  -k|--kerver:          Kernel Version
                            [default: $KER_VER]
  -i|--initrd:          Path to the initrd
                            [default: ${COMMON_INITRD_DIR}/\
${COMMON_INITRD_BASENAME}-kerver.unsigned]
  -n|--name:            Name to the UKI to generate 
                            [Default: $CREATE_DEFAULT_UKI_NAME]
  -c|--cmdline:         kernel cmdline
                            [Default: $CREATE_DEFAULT_CMDLINE]
  -o|--output:          Output dir where to generate the UKI.
                            [Default: $PWD]
  --pcrkeys :           Generate and use PCR keys for the generated UKI
                            Keys will be stored in ./<ukiname>.keys/
                            (see ukify genkey for more info)
  help:                 Print this helper
 
INFO:
    Generate PCR keys and use them to create an UKI using the systemd tool
'ukify'
 
EXAMPLE:
    $BIN create -k $KER_VER -n uki-0.1.0.efi -o ${COMMON_KERNEL_MODULESDIR}\
/$KER_VER/"
    printf "%s\n" "$usage_str"
}

### Generate PCR keys into a given directory
# ARGUMENTS:
#   1 - output dir
# OUTPUTS:
#   None
# RETURN:
#  0 in succes, >0 otherwise
###
_create_generate_pcr_keys() {
    err=0
    if [ "$1" = "" ]; then
        echo_error "Missing argument"
        err=1
    elif [ ! -d "$1" ]; then
        echo_error "No dir at $1"
        err=1
    fi
    output_dir="$1"
    if test -f "$output_dir"/pcr-initrd.key.pem \
       -o -f "$output_dir"/pcr-initrd.pub.pem \
       -o -f "$output_dir"/pcr-system.key.pem \
       -o -f "$output_dir"/pcr-system.pub.pem; then
        echo_info "PCR keys has already been created. Cancel."
    elif [ $err -eq 0 ]; then
        if $UKIFY genkey \
        --pcr-private-key="$output_dir"/pcr-initrd.key.pem \
        --pcr-public-key="$output_dir"/pcr-initrd.pub.pem \
        --phases='enter-initrd' \
        --pcr-private-key="$output_dir"/pcr-system.key.pem \
        --pcr-public-key="$output_dir"/pcr-system.pub.pem \
        --phases='enter-initrd:leave-initrd
            enter-initrd:leave-initrd:sysinit
            enter-initrd:leave-initrd:sysinit:ready'; then
            echo_info "PCR key generated"
        else
            echo_error "Failed to generate PCR key"
            err=1
        fi
    fi
    return $err
}

### Generate UKI
# ARGUMENTS:
#   1 - output dir
#   2 - generated PCR keys dir
#   3 - Kernel Version
#   4 - image name
#   5 - cmdline
#   6 - initrd
# OUTPUTS:
#   Location of the built UKI.
# RETURN:
#  0 in succes, >0 otherwise
###
_create_generate_uki() {
    output_dir="$1"
    pcrkeys_dir="$2"
    kerver="$3"
    name="$4"
    cmdline="$5"
    initrd_p="$6"
    err=0
    if [ $# -lt 6 ]; then
        echo_error "Missing arguments"
        err=1
    elif [ ! -d "${output_dir}" ]; then
        echo_error "No dir at ${output_dir}"
        err=1
    fi
    if [ $err -ne 1 ]; then
        set -- --initrd="${initrd_p}"
        set -- "$@" --linux="${COMMON_KERNEL_MODULESDIR}/${kerver}/${KER_NAME}"
        set -- "$@" --uname="${kerver}"
        set -- "$@" --output="${output_dir}/${name}"
        set -- "$@" --cmdline="${cmdline}"
        if test "${CREATE_GENKEYS}" = "y" -a -d "${pcrkeys_dir}"; then
            set -- "$@" --pcr-private-key="${pcrkeys_dir}/pcr-initrd.key.pem"
            set -- "$@" --pcr-public-key="${pcrkeys_dir}/pcr-initrd.pub.pem"
            set -- "$@" --phases='enter-initrd'
            set -- "$@" --pcr-private-key="${pcrkeys_dir}/pcr-system.key.pem"
            set -- "$@" --pcr-public-key="${pcrkeys_dir}/pcr-system.pub.pem"
            set -- "$@" --pcrpkey="${pcrkeys_dir}/pcr-system.pub.pem"
            set -- "$@" --phases='enter-initrd:leave-initrd
                enter-initrd:leave-initrd:sysinit
                enter-initrd:leave-initrd:sysinit:ready'
            set -- "$@" --pcr-banks=sha256
        fi
        if $UKIFY build "$@"; then
            echo_info "UKI generated: ${output_dir}/${name}"
        else
            echo_error "$UKIFY failed to create the UKI at ${output_dir}/\
${name}"
            err=1
        fi
    fi
    return $err
}

#######################################################################
#                           ENTRY POINT                               #
#######################################################################

###
# Print the helper of the create command
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   NONE
###
create_helper() {
    _create_usage
}

###
# Print the list of needed tool for the command
# OUTPUTS:
#   NONE
# RETURN:
#   lsit of needed tools
###
create_tools_needed() {
    printf "%s" "$CREATE_UKIFY_BIN"
}

###
# Execute the command create
# OUTPUTS:
#   None
# RETURN:
#   0 in success, >0 otherwise
###
create_exec() {
    printf "Execute command create\n"
    # Get arguments
    args=$(getopt -a -n extension -o k:i:n:c:o:\
        --long kerver:,initrd:,name:,cmdline:,output:,pcrkeys -- "$@")
    eval set --"$args"
    while :
    do
        case "$1" in
            -k | --kerver)      kerver="$2"         ; shift 2 ;;
            -i | --initrd)      initrd_path="$2"    ; shift 2 ;;
            -n | --name)        name="$2"           ; shift 2 ;;
            -c | --cmdline)     cmdline="$2"        ; shift 2 ;;
            -o | --output)      output="$2"         ; shift 2 ;;
            --pcrkeys)          CREATE_GENKEYS="y"  ; shift 1 ;;     
            --)                 shift               ; break   ;;
            *) echo_warning "Unexpected option: $1"; _create_usage   ;;
        esac
    done
    if [ ! ${kerver+x} ]; then
        kerver="$KER_VER"
    fi
    if [ ! ${initrd_path+x} ]; then
        initrd_path="${COMMON_INITRD_DIR}/${COMMON_INITRD_BASENAME}-$kerver"
        if [ ! -f "${initrd_path}" ]; then
            initrd_path="${initrd_path}.unsigned"
        fi
    fi
    if [ ! -f "${initrd_path}" ]; then
        echo_error "Unable to find an initrd at ${initrd_path}"
        return 1
    fi
    if [ ! ${name+x} ]; then
        name="$CREATE_DEFAULT_UKI_NAME"
    fi
    if [ ! ${cmdline+x} ]; then
        cmdline="$CREATE_DEFAULT_CMDLINE"
    fi
    if [ ! ${output+x} ]; then
        output="$PWD"
    fi
    keys_dir=""
    if [ "${CREATE_GENKEYS}" = "y" ]; then
        keys_dir="./${name}.keys"
        mkdir -p "$keys_dir"
        if _create_generate_pcr_keys "$keys_dir"; then
            echo_info "PCR keys generated in: $keys_dir/"
        else
            echo_error "Failed to generate PCR keys"
            return 1
        fi
    fi
    # Generate UKI
    _create_generate_uki "$output" "$keys_dir" "$kerver" "$name" "$cmdline" \
"$initrd_path"
}
