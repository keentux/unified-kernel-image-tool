#!/bin/sh

# This is the script to check the uki tool.
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

ukitool_path="./build/uki-tool"

if [ ! -f "${ukitool_path}" ]; then
    sh build.sh
fi

printf "%s " "--- Testing ..."
sh tests/test.sh --vm --clear