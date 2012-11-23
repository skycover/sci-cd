#!/bin/bash
# needed uuencode/decode (sharutils)
#

usage(){
  cat <<EOF >&2
partgen.sh -d DISKS [-v yes|no] -l [1|10|none]
  -d [DISKS|manual] - the number of disks for the system raid, starting from sda, default: 1
   Use "manual" for manual layout.
  -v - create /var partition (default are the root and swap partitions only)
  -l [LEVEL|none] - create RAID1/5/6/10 with lvm xenvg and xenvg/system-stuff
   LEVEL is the number, default: 1.
   If DISKS=1 then simple partition will be created instead of RAID.
   Use "none" if you wish to create LVM manually later - the "sci-setup xenvg"
   will offer you some options for this.
EOF
}

partvar=no
partlvm=yes
disks=1

while getopts "hp:d:v:l:" opt; do
  case $opt in
  h)
    usage
    exit 1
  ;;
  d)
    disks=$OPTARG
  ;;
  v)
    partvar=$OPTARG
  ;;
  l)
    partlvm=$OPTARG
  ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    usage
    exit 1
  ;;
  :)
    echo "Option -$OPTARG requires an argument" >&2
    usage
    exit 1
  ;;
  esac
done

test "$partvar" = "yes" || partvar=""

case $disks in
  manual)
  cat <<EOF
d-i grub-installer/only_debian boolean true

# Have manual partitioning
EOF
  ;;
  1)
  cat <<EOF
d-i grub-installer/only_debian boolean false
d-i grub-installer/with_other_os boolean false
d-i grub-installer/bootdev  string /dev/sda

EOF

  if [ "$partlvm" = "none" ]; then
    partlvm=""
  fi
  cat <<EOF
d-i partman-auto/method string regular
d-i partman-auto/disk string /dev/sda
d-i partman-auto/expert_recipe string root ::	\\
	10240 10 10240 ext4			\\
		\$lvmignore{ }					\\
		\$primary{ } \$bootable{ } method{ format }	\\
		format{ } use_filesystem{ } filesystem{ ext4 }	\\
		mountpoint{ / }					\\
	.							\\
	2048 20 2048 linux-swap					\\
		\$lvmignore{ }					\\
		\$primary{ } method{ swap } format{ }		\\
EOF
  if [ -n "$partvar" ]; then
    lvmvol=sda4
    cat <<EOF
	.							\\
	10240 20 10240 ext4					\\
		\$lvmignore{ }					\\
		\$primary{ } method{ format }			\\
		format{ } use_filesystem{ } filesystem{ ext4 }	\\
		mountpoint{ /var }				\\
EOF
  else
    lvmvol=sda3
  fi
  cat <<EOF
	.					\\
       	500 100 1000000000 lvm			\\
		\$primary{ }			\\
		use_filesystem{ }		\\
		filesystem{ lvm }		\\
		method{ keep }			\\
EOF
  cat <<EOF
	.
#d-i partman-auto/choose_recipe select root
d-i partman-basicfilesystems/no_mount_point boolean false
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select Finish partitioning and write changes to disk
d-i partman/alignment select cylinder
d-i partman/confirm boolean true
EOF
  if [ -n "$partlvm" ]; then
    cat <<EOF
# was unable to do in-target mount /stuff, so it woll done in postinst.sh
d-i preseed/late_command string vgcreate xenvg /dev/$lvmvol && lvcreate -L 20G -n system-stuff xenvg && mkfs.ext4 /dev/xenvg/system-stuff && echo "/dev/xenvg/system-stuff /stuff ext4 errors=remount-ro 0 0" >>/target/etc/fstab && mkdir /target/stuff
EOF
  fi
  ;;
  *)
  devices=`echo /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg /dev/sdh|cut -d' ' -f-$disks`
  grub_devices=`echo '(hd0,0) (hd1,0) (hd2,0) (hd3,0) (hd4,0) (hd5,0) (hd6,0) (hd7,0)'|cut -d' ' -f-$disks`
  if [ -z "$devices" ]; then
    echo "-d expects the number of disks"
    usage
    exit 1
  fi
  cat <<EOF
d-i grub-installer/only_debian boolean false
d-i grub-installer/with_other_os boolean false
d-i grub-installer/bootdev  string $devices

EOF
  if [ "$partlvm" = "none" ]; then
    partlvm=""
  elif [ "$partlvm" = "yes" ]; then
      partlvm=1
  fi
  # XXX needs check against no raid on one disk and sufficient disks for raid levels
  cat <<EOF
d-i partman-auto/method string raid
# Specify the disks to be partitioned. They will all get the same layout,
# so this will only work if the disks are the same size.
d-i partman-auto/disk string $devices
EOF
  if [ -n "$partlvm" ]; then
    cat <<EOF
d-i partman-lvm/confirm boolean true
d-i partman-auto-lvm/new_vg_name string xenvg
EOF
  fi
  cat <<EOF

# Next you need to specify the physical partitions that will be used. 
d-i partman-auto/expert_recipe string multiraid ::	\\
	10240 10 10240 raid			\\
		\$primary{ } method{ raid }	\\
	.					\\
	2048 20 2048 raid			\\
		\$primary{ } method{ raid }	\\
EOF
  if [ -n "$partvar" ]; then
    cat <<EOF
	.					\\
	10240 20 10240 raid			\\
		\$primary{ } method{ raid }	\\
EOF
  fi
  # we'll create the restful partition, but will not assemble it to the raid unless LVM is used
  cat <<EOF
	.					\\
       	500 100 1000000000 raid			\\
		\$primary{ } method{ raid }	\\
EOF
  if [ -n "$partlvm" ]; then
    cat <<EOF
	.					\\
	20480 20 20480 ext4			\\
		\$defaultignore{ }		\\
		\$lvmok{ }			\\
		lv_name{ system-stuff }		\\
		method{ format }		\\
		format{ }			\\
		use_filesystem{ }		\\
		filesystem{ ext4 }		\\
		mountpoint{ /stuff }		\\
	.					\\
       	500 100 1000000000 ext4			\\
		\$defaultignore{ }		\\
		\$lvmok{ }			\\
		lv_name{ removeit }		\\
		use_filesystem{ }		\\
		filesystem{ ext4 }		\\
		method{ keep }			\\
EOF
  fi
  cat <<EOF
       	.

# Last you need to specify how the previously defined partitions will be
# used in the RAID setup. Remember to use the correct partition numbers
# for logical partitions. RAID levels 0, 1, 5, 6 and 10 are supported;
# devices are separated using "#".
# Parameters are:
# <raidtype> <devcount> <sparecount> <fstype> <mountpoint> \\
#          <devices> <sparedevices>

EOF
  (echo -n d-i partman-auto-raid/recipe string" "
   echo -n 1 $disks 0 ext4 / `echo $devices|awk -vn=1 'BEGIN{OFS="#";ORS=""}{for(i=1; i<=NF; i++){$i=$i n}; print}'`.
   echo -n 1 $disks 0 swap - `echo $devices|awk -vn=2 'BEGIN{OFS="#";ORS=""}{for(i=1; i<=NF; i++){$i=$i n}; print}'`.
   if [ -n "$partvar" ]; then
     echo -n 1 $disks 0 ext4 / `echo $devices|awk -vn=3 'BEGIN{OFS="#";ORS=""}{for(i=1; i<=NF; i++){$i=$i n}; print}'`.
     lvmpartno=4
   else
     lvmpartno=3
   fi
   if [ -n "$partlvm" ]; then
     echo $partlvm $disks 0 lvm / `echo $devices|awk -vn=$lvmpartno 'BEGIN{OFS="#";ORS=""}{for(i=1; i<=NF; i++){$i=$i n}; print}'`.
   fi)
  cat <<EOF


# For additional information see the file partman-auto-raid-recipe.txt
# included in the 'debian-installer' package or available from D-I source
# repository.

# This makes partman automatically partition without confirmation.
d-i partman-md/confirm boolean true
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-basicfilesystems/no_mount_point boolean false
d-i partman/alignment select cylinder
EOF
  if [ -n "$partlvm" ]; then
  cat <<EOF
d-i preseed/late_command string lvremove -f /dev/xenvg/removeit
EOF
  fi
  ;;
esac
