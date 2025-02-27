#!/bin/sh

# This is the script to install the uki tool.
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

BUILDDIR="build"
BINNAME="uki-tool"
PREFIX="/"
BINDIR="/usr/bin"
MANDIR="/usr/share/man"

#######################################################################
#                           ENTRY POINT                               #
#######################################################################

args=$(getopt -a -n install -o p: --long prefix:,bindir:,mandir: -- "$@")
[ $? -eq 1 ] && exit 1
eval set --"$args"
while :
do
    case "$1" in
        -p | --prefix)  PREFIX="$(echo "$2" | sed 's_/$__')" ; shift 2 ;;
        --mandir)       MANDIR="$2"         ; shift 2 ;;
        --bindir)       BINDIR="$2"         ; shift 2 ;;
        --)             shift               ; break   ;;
        *) echo "Unexpected option: $1"     ; exit 1  ;;
    esac
done

# Install binary
[ "${BINDIR:0:1}" != "/" ] && BINDIR="/${BINDIR}"
BINPATH="${PREFIX}${BINDIR}"
if install -D -m 0755 \
    "${BUILDDIR}/${BINNAME}"\
    "${BINPATH}/${BINNAME}"; then
    echo "--- ${BINNAME} installed at ${BINPATH}"
else
    echo "--- Failed to install at ${PREFIX}${BINDIR}${BINNAME}"
fi

# Install manual
[ "${MANDIR:0:1}" != "/" ] && MANDIR="/${MANDIR}"
MANPATH="${PREFIX}${MANDIR}"
if install -D -m 644 \
    docs/man/uki-tool.1\
    "${MANPATH}/man1/uki-tool.1"; then
    echo "--- manual installed at ${MANPATH}/man1/uki-tool.1"
else
    echo "--- Failed to install at ${MANPATH}/man1/uki-tool.1"
fi