#!/bin/sh
if [ "$1" = "-h" ]; then
  cat <<EOF
Download the signed gplpv drivers from Univention and create gplpv/gplpv.iso
Note: http://wiki.univention.de/index.php?title=Installing-signed-GPLPV-drivers

usage: ./makegplpv.sh [-n|-t]
-n - don't download, just create iso
-t - download only if nothing is already downloaded in gplpv/univention
EOF
  exit
fi
mkdir -p gplpv/meadowcourt
cd gplpv/meadowcourt
test "$1" = "-n" || test "$1" = "-t" -a -n "$(ls -A)" ||  wget -r --no-parent -l1 -nd http://www.meadowcourt.org/downloads/
cd ..
genisoimage -o gplpv.iso -R -J -hfs meadowcourt
