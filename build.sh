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

CMD="help"
CMD_DIR="commands"
BUILD_DIR="build"
SCRIPT="ukit"
SCRIPT_PATH="$BUILD_DIR/$SCRIPT"

clean() {
    [ -d ./$BUILD_DIR ] && rm -r ./$BUILD_DIR
}

check_cmd_function() {
    if ! grep "$2" < "./${CMD_DIR}/${1}" > /dev/null; then
        echo "Missing function ${2} in ./${CMD_DIR}/${1}"
        return 1
    fi
    return 0
}

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

# Checking scripts format
echo "--- Checking ..."
for file in ./"$CMD_DIR"/*; do
    if ! shellcheck "$file"; then
        echo "ShellCheck return somes errors/warning for $file"
        exit 2
    fi
done

# Clean and Create the build directory
echo "--- Preparing ..."
clean
mkdir ./$BUILD_DIR
touch ./$SCRIPT_PATH
echo "#!/bin/sh" >> $SCRIPT_PATH

# Put the needed global variables
echo "--- Building ..."
if ! list_all_cmds; then
    rm -r ./$BUILD_DIR
    exit 1
fi
{
    echo "CMD=\"$CMD\""
    echo "BIN=\"$SCRIPT\""
    echo "VERBOSE=0"
} >> $SCRIPT_PATH

# Put the commands scripts functions
for file in ./"$CMD_DIR"/*; do
    insert_script "$file"
done

# Put the main scripts
insert_script ./main.sh
chmod +x "$SCRIPT_PATH"
echo "--- Finished [Build: $SCRIPT_PATH]"