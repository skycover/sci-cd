#!/bin/bash
# needed uuencode/decode (sharutils)
#

usage(){
  cat <<EOF >&2
build.sh [-p PROFILE] -d DISKS -v -l [1|10|none]
  -p PROFILE  - default: SCI-amd64
  -d [DISKS|manual] - the number of disks for the system raid, starting from sda, default: 1
   Use "manual" for manual layout.
  -v - create /var partition (default are the root and swap partitions only)
  -l [LEVEL|none] - create RAID1/5/6/10 with lvm xenvg and xenvg/system-stuff
   LEVEL is the number, default: 1.
   If DISKS=1 then simple partition will be created instead of RAID.
   Use "none" if you wish to create LVM manually later - the "sci-setup xenvg"
   will offer you some options for this.
   NOTE: if DISKS=1 then -l will be always "none" to fix a problem with partman.
EOF
}

if [ ! -x /usr/bin/uuencode ]; then
 echo Please install sharutils
 exit 1
fi

profile=SCI-amd64
partlvm=yes
disks=1

while getopts "hp:d:vl:" opt; do
  case $opt in
  h)
    usage
    exit 1
  ;;
  p)
    profile=$OPTARG
  ;;
  d)
    disks=$OPTARG
  ;;
  V)
    partvar=yes
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

case $disks in
  manual)
  cat <<EOF >profiles/partman.tmp
d-i grub-installer/only_debian boolean true

# Have manual partitioning
EOF
  ;;
  1)
  cat <<EOF >profiles/partman.tmp
d-i grub-installer/only_debian boolean false
d-i grub-installer/with_other_os boolean false
d-i grub-installer/bootdev  string /dev/sda

EOF

  # XXX Can't create LVM with two primaty partitions before it
  partlvm=none

  if [ "$partlvm" = "none" ]; then
    partlvm=""
    echo "Warning: you should use 'sci-setup xenvg' after the installation"
  fi
  if [ -n "$partlvm" ]; then
    cat <<EOF >>profiles/partman.tmp
d-i partman-auto/method string lvm
#d-i partman-lvm/confirm boolean true
d-i partman-auto-lvm/new_vg_name string xenvg
EOF
  else
    cat <<EOF >>profiles/partman.tmp
d-i partman-auto/method string regular
EOF
  fi
  cat <<EOF >>profiles/partman.tmp
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
    cat <<EOF >>profiles/partman.tmp
	.							\\
	10240 20 10240 ext4					\\
		\$lvmignore{ }					\\
		\$primary{ } method{ format }			\\
		format{ } use_filesystem{ } filesystem{ ext4 }	\\
		mountpoint{ /var }				\\
EOF
  fi
  if [ -n "$partlvm" ]; then
    cat <<EOF >>profiles/partman.tmp
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
  else
    cat <<EOF >>profiles/partman.tmp
	.					\\
       	500 100 1000000000 ext4			\\
		\$primary{ }			\\
		use_filesystem{ }		\\
		filesystem{ ext4 }		\\
		method{ keep }			\\
EOF
  fi
  cat <<EOF >>profiles/partman.tmp
	.
#d-i partman-auto/choose_recipe select root
d-i partman-basicfilesystems/no_mount_point boolean false
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select Finish partitioning and write changes to disk
d-i partman/alignment select cylinder
d-i partman/confirm boolean true
EOF
  if [ -n "$partlvm" ]; then
    cat <<EOF >>profiles/partman.tmp
d-i preseed/late_command string lvremove -f /dev/xenvg/removeit
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
  cat <<EOF >profiles/partman.tmp
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
  cat <<EOF >>profiles/partman.tmp
d-i partman-auto/method string raid
# Specify the disks to be partitioned. They will all get the same layout,
# so this will only work if the disks are the same size.
d-i partman-auto/disk string $devices
EOF
  if [ -n "$partlvm" ]; then
    cat <<EOF >>profiles/partman.tmp
d-i partman-lvm/confirm boolean true
d-i partman-auto-lvm/new_vg_name string xenvg
EOF
  fi
  cat <<EOF >>profiles/partman.tmp

# Next you need to specify the physical partitions that will be used. 
d-i partman-auto/expert_recipe string multiraid ::	\\
	10240 10 10240 raid			\\
		\$primary{ } method{ raid }	\\
	.					\\
	2048 20 2048 raid			\\
		\$primary{ } method{ raid }	\\
EOF
  if [ -n "$partvar" ]; then
    cat <<EOF >>profiles/partman.tmp
	.					\\
	10240 20 10240 raid			\\
		\$primary{ } method{ raid }	\\
EOF
  fi
  # we'll create the restful partition, but will not assemble it to the raid unless LVM is used
  cat <<EOF >>profiles/partman.tmp
	.					\\
       	500 100 1000000000 raid			\\
		\$primary{ } method{ raid }	\\
EOF
  if [ -n "$partlvm" ]; then
    cat <<EOF >>profiles/partman.tmp
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
  cat <<EOF >>profiles/partman.tmp
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
   fi) >>profiles/partman.tmp
  cat <<EOF >>profiles/partman.tmp


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
d-i preseed/late_command string lvremove -f /dev/xenvg/removeit
EOF
  ;;
esac

awk '//{print}/#### INCLUDE PARTMAN ####/{exit}' profiles/default.preseed.$profile.in >profiles/default.preseed
cat profiles/partman.tmp >>profiles/default.preseed
awk '//{if(s)print}/#### INCLUDE PARTMAN ####/{print "#### PARTMAN INCLUDED ####"; s=1}' profiles/default.preseed.$profile.in >>profiles/default.preseed

if [ -d profiles/$profile.files ]; then
 cd profiles
 script=$profile.postinst
 tarfile=$profile.tar
 workdir=/usr/local/simple-cdd
 rm -rf $profile.files/target
 rm -rf $profile.files/backup
 tar cf $tarfile $profile.files
 cat <<EOF >$script
mkdir -p $workdir
cd $workdir
/usr/bin/uudecode -o- << "EOF" | tar x
EOF
 uuencode $tarfile $tarfile >>$script 
 echo EOF >>$script
 cat <<EOF >>$script
cd $profile.files
test -x postinst.sh && ./postinst.sh real >postinst.log 2>&1
EOF
 chmod +x $script
 rm $tarfile
 cd ..
fi 

if [ -d local ]; then
 lpackages="--local-packages local"
fi
build-simple-cdd $lpackages --conf profiles/$profile.conf
