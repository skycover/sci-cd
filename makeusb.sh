#!/bin/sh
# Make bootable usb
# http://www.enricozini.org/2008/tips/simple-cdd-usb/
# You'll need # apt-get install syslinux mtools mbr
# Should be runned as root
# After done, copy the resulting iso to the usb key


if [ -z "$1" -o ! -f "$1" ]; then
 echo This tool will prepare a bootable usb key
 echo "You'll need # apt-get install syslinux mtools mbr"
 echo "You should run it as root from the root of sci-cd work area (from here)"
 echo ""
 echo "Usage: $0 /dev/sdX"
 echo "Where X is the usb key disk label (without a partition)"
 exit 1
fi
d=$1
mkdir -p usbkey
cd usbkey
test -f initrd.gz || wget http://ftp.uk.debian.org/debian/dists/squeeze/main/installer-amd64/current/images/hd-media/initrd.gz
test -f vmlinuz || wget http://ftp.uk.debian.org/debian/dists/squeeze/main/installer-amd64/current/images/hd-media/vmlinuz
# this is not obligate and will erase all the contents
#mkdosfs ${d}1
syslinux ${d}1
install-mbr $d
mount ${d}1 /mnt
cp initrd.gz vmlinuz /mnt
grep append tmp/cd-build/squeeze/boot1/isolinux/txt.cfg | head -1 | sed -e 's/^\t//' -e 's/ initrd=[^ ]*/ initrd=initrd.gz/' >>/mnt/syslinux.cfg
echo "Now you can copy any *.iso image directly to usb filesystem (currently mounted on /mnt)"
