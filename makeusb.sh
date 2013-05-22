#!/bin/sh
# Make bootable usb
# http://www.enricozini.org/2008/tips/simple-cdd-usb/
# You'll need # apt-get install syslinux mtools mbr
# Should be runned as root
# After done, copy the resulting iso to the usb key

# variables
target=/mnt  # mount point for flash filesystem
d=$1 # block device path

# argument check - is it exist and is block device
if [ -z "$1" -o ! -b "$1" ]; then
 echo This tool will prepare a bootable usb key
 echo "You'll need # apt-get install syslinux mtools mbr"
 echo "You should run it as root from the root of sci-cd work area (from here)"
 echo ""
 echo "Usage: $0 /dev/sdX"
 echo "Where X is the usb key disk label (without a partition)"
 exit 1
fi

mkdir -p usbkey
cd usbkey
test -f initrd.gz || wget http://ftp.uk.debian.org/debian/dists/wheezy/main/installer-amd64/current/images/hd-media/initrd.gz
test -f vmlinuz || wget http://ftp.uk.debian.org/debian/dists/wheezy/main/installer-amd64/current/images/hd-media/vmlinuz
# this is not obligate and will erase all the contents
#mkdosfs ${d}1
syslinux ${d}1
install-mbr $d
mount ${d}1 "$target"
cp initrd.gz vmlinuz "$target"
echo "default vmlinuz" > "$target"/syslinux.cfg
grep append ../tmp/cd-build/wheezy/boot1/isolinux/txt.cfg | head -1 | sed -e 's/^\t//' -e 's/ initrd=[^ ]*/ initrd=initrd.gz/' >>"$target"/syslinux.cfg
echo "Now you can copy any *.iso image directly to usb filesystem (currently mounted on \"$target\")"
