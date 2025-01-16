#!/bin/sh
cd /buildroot
sh ./build.sh
sh ./install.sh -p $DESTDIR

#Install test files
mkdir -p $DESTDIR/root
cp -r tests $DESTDIR/root/
