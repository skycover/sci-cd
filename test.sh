#!/bin/sh
# You need to install quemu and kvm
# And prepare quemu-test.hd[ab].img with smething like
# dd if=/dev/zero of=qemu-test.hdX.img bs=100k count=20000

method=c
if [ "$1" = "inst" ]; then
 method=d
fi

kvm -enable-kvm -hda qemu-test.hda.img -hdb qemu-test.hdb.img -cdrom images/debian-SkyCover-amd64-CD-1.iso -boot $method
