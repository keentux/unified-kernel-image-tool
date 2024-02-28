#!/bin/sh

# This is the script to install the uki tool.
#
# Copyright 2024 Valentin LEFEBVRE <valentin.lefebvre@suse.com>
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

BUILD_DIR="build"
BIN_NAME="ukit"

if [ ! ${PREFIX_BIN_DIR+x} ]; then
    PREFIX_BIN_DIR="/usr"
fi
if [ ! -e "$PREFIX_BIN_DIR/bin" ]; then
    mkdir -p "$PREFIX_BIN_DIR/bin"
fi

if install -m 0755 \
    "$BUILD_DIR/$BIN_NAME"\
    "$PREFIX_BIN_DIR/bin/$BIN_NAME"; then
    echo "--- Installed at $PREFIX_BIN_DIR/bin/$BIN_NAME"
else
    echo "--- Failed to install at $PREFIX_BIN_DIR/bin/$BIN_NAME"
fi