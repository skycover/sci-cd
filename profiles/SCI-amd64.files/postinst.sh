#!/bin/bash
# this is the post-install script
# the newly-installed system is not yet booted, but chrooted at the moment of execution

set -x

export PATH=/usr/bin:/bin:/usr/sbin:/sbin
# XXX needed for handling around reloc_domain

# Preset vlan for standard interface
# To change, set the value in postinst.conf
vlan_no=""

if [ -f postinst.conf ]; then
 . postinst.conf
fi

if [ "$1" = "real" ]; then
 target=""
else # prepare test environment
 if [ `id -u` -eq 0 ]; then
   echo "Please don't run test mode as root, because it can modify your system accidentally!"
   exit 1
 fi
 rm -rf target
 cp -a target-orig target
 target=target
 mkdir -p $target/etc/xen $target/usr/sbin $target/usr/share/ganeti $target/usr/lib/xen $target/usr/local/sbin
fi

cp -a real/* .

mkdir -p backup
for i in \
 /etc/network/interfaces \
 /etc/hosts \
 /etc/hostname \
 /etc/xen/xend-config.sxp \
 /etc/default/grub \
 /etc/default/puppet \
 /etc/default/xendomains \
 /etc/modules \
 /etc/rsyslog.conf \
 /etc/dhcp/dhclient.conf
do
 cp $target/$i backup
done

## Setting up default grub entry - 'Debian GNU/Linux, with Linux 2.6.*-xen-amd64 and XEN 4.0-*'
dpkg-divert --divert /etc/grub.d/08_linux_xen --rename /etc/grub.d/20_linux_xen
update-grub
## Adding hypervisor option dom0_mem=512M
grub_file=$target/etc/default/grub
if [ -f $grub_file ]; then
 echo Configuring GRUB 
 ./strreplace.sh $grub_file "^GRUB_CMDLINE_XEN" 'GRUB_CMDLINE_XEN="dom0_mem=512M"'
 # XXX there is no setting separately for xenkopt
 # XXX with nosmp md raid is not loading with hypervisor menuentry
 #echo 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX nosmp"' >>$grub_file
 test -z "$target" && update-grub
else
 echo Not configuring GRUB
fi

## Set /var/log/kern.log to unbuffered mode

./strreplace.sh $target/etc/rsyslog.conf "^kern\.\*[\t ]+-\/var\/log\/kern.log" 'kern.*\t\t\t\t/var/log/kern.log'

## Set hostname to fqdn
## Set xend-config.sxp: xend-relocation-hosts-allow to allow relocation from local domain

hostname=`head -1 $target/etc/hostname`
if [ -n "$hostname" ]; then
ipaddr=`grep $hostname $target/etc/hosts|awk '{print $1}'`
hostfqdn=`grep $hostname $target/etc/hosts|awk '{print $2}'`
domain=`grep $hostname $target/etc/hosts|awk '{sub("^[^.]*\.","",$2); print $2}'`
reloc_domain=`awk -v d="$domain" 'BEGIN{gsub("[.]","\\\\\\\\\\\\\\\\.",d);print d; exit}'`
if [ -n "$domain" -a -n "$ipaddr" ]; then
 echo Configuring host/domainname stuff for $ipaddr $fqdn
 if [ "$hostname" = "$hostfqdn" ]; then
  echo Hostname configuration already ok
 else
  echo $hostfqdn >$target/etc/hostname
  ./strreplace.sh xend-config.sxp "^\(xend-relocation-hosts-allow" "(xend-relocation-hosts-allow '^localhost$ ^gnt[0-9]+\\\\\\\\.$reloc_domain\$')"
  mkdir -p $target/etc/xen
  cp xend-config.sxp $target/etc/xen
 fi
else
 echo Not configuring host/domainname stuff
fi
fi

## Assign supersede parameters for node's dhcp
dns=`grep nameserver $target/etc/resolv.conf|awk '{print $2; exit}'\;`
./strreplace.sh $target/etc/dhcp/dhclient.conf "^#supersede domain-name" "supersede domain-name $domain\;\nsupersede domain-name-servers $dns\;"

## Set default interface to be bridged, optionally with vlan (see postinst.conf)
## Set mtu 9000 on the default interface

echo Configuring interfaces
ifs=$target/etc/network/interfaces
iface=`awk '/^iface /{if($2 != "lo"){print $2;exit}}' $ifs`

cat <<EOF >interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

EOF
xenif=$iface
vif=$iface.$vlan_no
if [ -n "$vlan_no" ]; then
 cat <<EOF >>interfaces
auto $iface
iface $iface inet manual
        up ifconfig $iface up

auto $vif
iface $vif inet manual
        up ifconfig $vif up

EOF
 xenif=$vif
fi

cat <<EOF >>interfaces
auto xen-br0
iface xen-br0 inet static
EOF

awk '/^[ \t]*(address|netmask|network|broadcast|gateway)/' $ifs >>interfaces
cat <<EOF >>interfaces
        bridge_ports $xenif
        bridge_stp off
        bridge_fd 0
#	up ifconfig $xenif mtu 9000
#	up ifconfig xen-br0 mtu 9000
EOF
 
## Add example of additional interfaces

cat <<EOF >>interfaces

# The example of dhcp-configured LAN interface
# on the second ethernet card
#
#auto xen-lan
#iface xen-lan inet dhcp
#        bridge_ports eth1
#        bridge_stp off
#        bridge_fd 0

# The example of addidtional VLAN interface with bridge
# w/o assigning node any IP address
#
#auto eth0.VLAN_NO
#iface eth0.VLAN_NO inet manual
#        up ifconfig eth0.VLAN_NO up
#
#auto xen-VLAN_NAME
#iface xen-VLAN_NAME inet manual
#        up brctl addbr xen-VLAN_NAME
#        up brctl addif xen-VLAN_NAME eth0.8
#        up brctl stp xen-VLAN_NAME off
#        up ifconfig xen-VLAN_NAME up
#        down ifconfig xen-VLAN_NAME down
#        down brctl delbr xen-VLAN_NAME
EOF

cat interfaces >$ifs

## Set up module loading (drbd, 8021q)

echo Setting up modules
echo options drbd minor_count=128 usermode_helper=/bin/true >>$target/etc/modprobe.d/drbd
echo drbd >>$target/etc/modules
echo 8021q >>$target/etc/modules

## Allow plugins and facts syncing for puppet
echo Editing puppet.conf
echo "pluginsync = true" >>$target/etc/puppet/puppet.conf

## Enable puppet to start

echo Setting up defaults
./strreplace.sh $target/etc/default/puppet "^START=" "START=yes"

## Disable xendomains saving options

./strreplace.sh $target/etc/default/xendomains "^XENDOMAINS_SAVE" 'XENDOMAINS_SAVE=""'

## Add startup script rc.sci to setup performance

# a bit ugly, but fast ;)
cat <<EOF >$target/etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.

if [ -f /etc/rc.sci ]; then
  . /etc/rc.sci
fi

exit 0
EOF
chmod +x $target/etc/rc.local

## Add "xm sched-credit -d0 -w512" to rc.sci
# equal priority of Dom0 make problems on the block devices

## Tune storage scheduler for better disk latency
cat <<EOFF >$target/etc/rc.sci
#!/bin/sh
# On-boot configuration for hardware for better cluster performance
# mostly http://code.google.com/p/ganeti/wiki/PerformanceTuning

# rise priority for dom0, alowing drbd to work fine
xm sched-credit -d0 -w512

modprobe sg
disks=\`sg_map -i|awk '{if(\$3=="ATA"){print substr(\$2, length(\$2))}}'\`
for i in \$disks; do
  # Set value if you want to use read-ahead
  ra="$read_ahead"
  if [ -n "\$ra" ]; then
    blockdev --setra \$ra /dev/sd\$i
  fi
  if grep -q sd\$i /etc/sysfs.conf; then
    echo sd\$i already configured in /etc/sysfs.conf
  else
 cat <<EOF >>/etc/sysfs.conf
block/sd\$i/queue/scheduler = deadline
block/sd\$i/queue/iosched/front_merges = 0
block/sd\$i/queue/iosched/read_expire = 150
block/sd\$i/queue/iosched/write_expire = 1500
EOF
  fi
done
/etc/init.d/sysfsutils restart
EOFF
chmod +x $target/etc/rc.sci

## Add tcp buffers tuning for drbd
## Tune disk system to avoid (or reduce?) deadlocks
cat <<EOF >$target/etc/sysctl.d/sci.conf
# Increase "minimum" (and default) 
# tcp buffer to increase the chance to make progress in IO via tcp, 
# even under memory pressure. 
# These numbers need to be confirmed - probably a bad example.
#net.ipv4.tcp_rmem = 131072 131072 10485760 
#net.ipv4.tcp_wmem = 131072 131072 10485760 

# add disk tuning options to avoid (or reduce?) deadlocks
# gives better latency on heavy load
vm.swappiness = 0
vm.overcommit_memory = 1
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.dirty_expire_centisecs = 1000
EOF

## Add workaround for bnx2x NIC on HP Proliant and Blade servers
# https://bugzilla.redhat.com/show_bug.cgi?id=518531
echo "options bnx2x disable_tpa=1" >$target/etc/modprobe.d/sci.conf

## Set up symlinks /boot/vmlinuz-2.6-xenU, /boot/initrd-2.6-xenU

# we'll assume only one xen kernel at the moment of the installation
ln -s $target/boot/vmlinuz-2.6.*-xen-amd64 $target/boot/vmlinuz-2.6-xenU
ln -s $target/boot/initrd.img-2.6.*-xen-amd64 $target/boot/initrd.img-2.6-xenU

## Set up symlink /usr/lib/xen for quemu-dm (workaround)
ln -s $target/usr/lib/xen-4.0 $target/usr/lib/xen

## Set vnc master password if provided in postinst.conf
echo "${vnc_cluster_password:=gntwin}" >$target/etc/ganeti/vnc-cluster-password
chmod 600 $target/etc/ganeti/vnc-cluster-password

if [ ! -f /proc/mounts ]; then
	echo Warning: /proc is not mounted. Trying to fix.
	mkdir -p /proc
	mount /proc
	proc_mounted=1
fi

## Create RAID10 with far layout and LVM/xenvg
# if there is xenvg_disks and xenvg_md then try to create RAID and LVM
# else expect the xenvg is already configured
if [ -n "$xenvg_disks" -a -n "$xenvg_md" ]; then
  echo ...Creating RAID10 with far layout
  # No preexisting checks - it should simply fail the already completed phases
  ndisks=`ls $xenvg_disks|wc -w`
  if [ -n "$xenvg_spares" ]; then
    spares="`ls $xenvg_spares|wc -w` $xenvg_spares"
  fi
  echo "CALLING: mdadm --create -l 10 -n $ndisks --layout=${md_layout:-n2} $xenvg_md $xenvg_disks $spares"
  mdadm --create -l 10 -n $ndisks --layout=${md_layout:-n2} $xenvg_md $xenvg_disks $spares
  /usr/share/mdadm/mkconf >$target/etc/mdadm/mdadm.conf
  # XXX is it needed? will -u reflect right kernel? or better will be -a?
  #update-initramfs -u
  vgcreate xenvg $xenvg_md
fi

## Prepare LVM/xenvg/system-stuff on /stuff for cd images, dumps etc.
# if /stuff is already present, let's suppose that it is fully configured
if [ ! -d $target/stuff ]; then
  echo ...Creating /stuff volume
  mkdir $target/stuff
  # don't touch data if volume exists
  if [ ! -b /dev/xenvg/system-stuff ]; then
    echo "CALLING: lvcreate -v -L ${stuff_volume_size:-20G} -n system-stuff xenvg"
    lvcreate -v --noudevsync -L ${stuff_volume_size:-20G} -n system-stuff xenvg
    if [ $? -eq 0 ]; then
      sleep 1 # XXX for a case
      if [ -b /dev/xenvg/system-stuff ]; then
	echo ...Formatting new xenvg/system-stuff
	mkfs.ext4 /dev/xenvg/system-stuff
      fi
    fi
  fi
  # recheck volume and mount
  if [ -b /dev/xenvg/system-stuff ]; then
    echo "/dev/xenvg/system-stuff /stuff ext4 errors=remount-ro 0 0" >>$target/etc/fstab
    mount /stuff
  fi
fi

## Set up CD-ROM repository: create /stuff/cdimages, /media/sci

echo Setting up local CD-ROM repository
mkdir -p $target/stuff/cdimages
mkdir -p $target/media/sci

cat <<EOF >>$target/etc/apt/apt.conf.d/99-sci
Acquire::cdrom::mount "/media/sci";
APT::CDROM::NoMount;
EOF

## Set up ganeti-instance-debootstrap source to local SCI-CD image

cat <<EOF >>$target/etc/default/ganeti-instance-debootstrap
MIRROR=file:/media/sci/
ARCH=amd64
SUITE=squeeze
EXTRA_PKGS="linux-image-xen-amd64"
EOF

## Copy-in SCI-CD iso image to /stuff/cdimages, mount to /media/sci, set up sources.list

# when installing from USB stick, two /cdrom mounts are shown
# XXX 'head -1' may be a wrong choice here, but will not differ them at present
dev=`grep '/cdrom' /proc/mounts|head -1|cut -d' ' -f1`

if [ -n "$dev" -a -e "$dev" ]; then
	echo ...Copying CD-ROM image
	dd if=$dev of=$target/stuff/cdimages/sci.iso

	echo "/stuff/cdimages/sci.iso /media/sci iso9660 loop 0 1" >>$target/etc/fstab

	echo ...Adding repository data
	mount /media/sci && (apt-cdrom -d=/media/sci add; umount /media/sci)
else
	echo Unable to find CD-ROM device
	echo "#/stuff/cdimages/sci.iso /media/sci iso9660 loop 0 1" >>$target/etc/fstab
fi

test -n "$proc_mounted" && umount /proc
umount /stuff

## Link /var/lib/ganeti/export to /stuff/export

mkdir $target/stuff/export
(cd $target/var/lib/ganeti && ln -s $target/stuff/export)

## Patch ganeti for viridian option

source=`pwd`
(cd $target/usr/share/pyshared/ganeti; patch -p1 <$source/patch/ganeti-2.5.0-viridian.patch)

## Add ganeti hooks if any

mkdir -p $target/etc/ganeti/hooks
cp -r files/ganeti/hooks $target/etc/ganeti/

## Add ganeti-instance-debootstrap hooks for pygrub and SCI-CD

mkdir -p $target/etc/ganeti/instance-debootstrap/hooks
cp -r files/ganeti/instance-debootstrap/hooks/* $target/etc/ganeti/instance-debootstrap/hooks/

## Add ganeti-instance-debootstrap variant "sci"

mkdir -p $target/etc/ganeti/instance-debootstrap/variants
cp -r files/ganeti/instance-debootstrap/variants/* $target/etc/ganeti/instance-debootstrap/variants/
echo sci >>$target/etc/ganeti/instance-debootstrap/variants.list

## Add ganeti OS "windows" scripts (ntfsclone - based) and simple "raw"

cp -r files/os $target/usr/share/ganeti/

## Add SCI deploing scripts
## Make LV names 'system-.*' ignored by ganeti

cp files/sbin/* $target/usr/local/sbin/

## Filling SCI configuration template

mkdir $target/etc/sci
cat <<EOF >$target/etc/sci/sci.conf
# The cluster's name and IP. They MUST be different from node names
# The cluster's IP will be an interface alias on the current master node
CLUSTER_NAME=
CLUSTER_IP=

# The first (master) node data
# Autofilled on install. On the nodes other than master may be differ, unless synced
NODE1_NAME=$hostname
NODE1_IP=$ipaddr
NODE1_SAN_IP=

# The second node data
NODE2_NAME=
NODE2_IP=
NODE2_SAN_IP=

#master netdev name
MASTER_NETDEV=xen-br0
LINK_NETDEV=xen-br0

#reserved volumes - what lvm used by nodes system not by cluster(comma separated)
RESERVED_VOLS="xenvg/system-.*"

# sources for approx apt cache server on sci
# all two together must be non empty, or nonexistent
APT_DEBIAN="debian http://ftp.debian.org/debian/"
APT_SECURITY="security http://security.debian.org/"

# forwarders for DNS server on sci
# use syntax "1.2.3.4; 1.2.3.4;"
DNS_FORWARDERS=""

EOF