#!/bin/bash

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

function clean() {
    [ -d ./$BUILD_DIR ] && rm -r ./$BUILD_DIR
}

function list_all_cmds() {
    local name
    local cmd
    for file in ./"$CMD_DIR"/*; do
        name=$(basename "$file")
        cmd=${name%.*}
        CMD+=" $cmd"
    done
}

function insert_script() {
    script=$1
    while IFS= read -r line; do
        [[ (! "$line" =~ ^"#") && ("$line" != "") ]] && echo "$line" >> $SCRIPT_PATH
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
echo "--- Preparaing ..."
clean
mkdir ./$BUILD_DIR
touch ./$SCRIPT_PATH
echo "#!/bin/bash" >> $SCRIPT_PATH

# Put the needed global variables
echo "--- Building ..."
list_all_cmds
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