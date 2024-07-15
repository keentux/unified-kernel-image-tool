#!/bin/sh

# This is the script to build the uki tool.
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

SRC_DIR="src"
CMD="help"
CMD_DIR="${SRC_DIR}/commands"
BUILD_DIR="build"
SCRIPT="uki-tool"
SCRIPT_PATH="${BUILD_DIR}/${SCRIPT}"

#######################################################################
#                           BUILD FUNCTION                            #
#######################################################################

###
# Clean build env
# GLOBAL:
#   BUILD_DIR
# RETURN:
#   None
###
build_clean() {
    [ -d ./$BUILD_DIR ] && rm -r ./$BUILD_DIR
}

###
# Check if all methods are implemented in a command's script
# GLOBAL:
#   CMD_DIR
# RETURN:
#   0 if ok, 1 otherwise
###
check_cmd_function() {
    if ! grep "$2" < "./${CMD_DIR}/${1}" > /dev/null; then
        echo "Missing function ${2} in ./${CMD_DIR}/${1}"
        return 1
    fi
    return 0
}

###
# List all developped cmd and check if all methods are implemented
# GLOBAL:
#   CMD_DIR
#   CMD
# RETURN:
#   1 if error
###
list_all_cmds() {
    for file in ./"$CMD_DIR"/*; do
        errorCMD=0
        name="$(basename "$file")"
        cmd=${name%.*}
        for func in "exec" "tools_needed" "helper"; do
            if ! check_cmd_function "${name}" "${cmd}_${func}()"; then
                errorCMD=1
            fi
        done
        [ $errorCMD -eq 1 ] && return 1
        CMD="$CMD $cmd"
    done
}

###
# Insert a script into the final tool
# ARGUMENTS:
#   1 - path to the script to add
# GLOBAL:
#   SCRIPT_PATH
# RETURN:
#   None
###
insert_script() {
    script=$1
    idx=0
    while IFS= read -r line; do
        idx=$((idx+1))
        if expr "$line" : "^#" > /dev/null; then
            if expr "$line" : "^#!" > /dev/null && [ "$idx" -gt 10 ]; then
                echo "$line" >> $SCRIPT_PATH
            fi
        elif expr "$line" : "^export " > /dev/null; then
            echo "$line" | sed 's|export ||g' >> $SCRIPT_PATH
        elif [ "$line" != "" ]; then
            echo "$line" >> $SCRIPT_PATH
        fi
    done < "$script"
    echo "$line" >> $SCRIPT_PATH
}

###
# Print the usage help
# OUTPUTS:
#   Write helper to stdout
# RETURN:
#   2
###
build_usage() {
    usage_str="USAGE: sh build.sh [OPTIONS]
OPTIONS:
  check:                Use shellcheck to check script sh
  clean:                Clean build env
  help:                 Print this helper
 
INFO:
    Build the uki tool
 
EXAMPLE:
    sh build.sh check"
    printf "%s\n" "$usage_str"
}

###
# Use shellcheck to check scripts.
# OUTPUTS:
#   Status info
# GLOBAL:
#   SCRIPT_PATH
#   CMD_DIR
# RETURN:
#   2 if shellcheck is missing, exit1 if error
###
build_check() {
    if ! command -v shellcheck > /dev/null 2>&1; then
        return 2
    fi
    for file in ${SRC_DIR}/main.sh ${SRC_DIR}/common.sh ./"$CMD_DIR"/* ; do
        if ! shellcheck "$file"; then
            echo "ShellCheck return somes errors/warning for $file"
            exit 1
        fi
    done
}

###
# Clean and create the build dir
# OUTPUTS:
#   Status info
# GLOBAL:
#   SCRIPT_PATH
#   BUILD_DIR
# RETURN:
#   None
###
build_prepare() {
    build_clean
    mkdir "./$BUILD_DIR"
    touch "./$SCRIPT_PATH"
    echo "#!/bin/sh" >> "$SCRIPT_PATH"
}

#######################################################################
#                           ENTRY POINT                               #
#######################################################################

case "$1" in 
    help)   build_usage && exit 0 ;;
    check)  build_check && exit 0 ;;
    clean)  {
        printf "%s " "--- Cleaning ..."
        build_clean
        printf "%s\n" "OK!"
        exit 0
    } ;;
esac


# Checking scripts format
printf "%s " "--- Checking ..."
build_check
if [ "$?" -eq "2" ]; then
    printf "%s\n" "NOK! Missing shellcheck tool"
else
    printf "%s\n" "OK!"
fi

# Clean and Create the build directory
printf "%s " "--- Preparing ..."
build_prepare
printf "%s\n" "OK!"

# Put the needed global variables
printf "%s " "--- Building ..."
if ! list_all_cmds; then
    build_clean
    exit 1
fi
{
    echo "CMD=\"$CMD\""
    echo "BIN=\"$SCRIPT\""
    echo "VERBOSE=0"
} >> "$SCRIPT_PATH"

# Put the commands scripts functions
insert_script ${SRC_DIR}/common.sh
for file in ./"$CMD_DIR"/*; do
    insert_script "$file"
done

# Put the main scripts
insert_script ${SRC_DIR}/main.sh
chmod +x "$SCRIPT_PATH"
printf "%s\n" "OK!"
printf "%s\n" "--- Finished [Build: $SCRIPT_PATH]"