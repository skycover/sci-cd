#!/bin/bash
# this is the post-install script
# the newly-installed system is not yet booted, but chrooted at the moment of execution
# XXX xend-relocation-hosts is turned off (can be tuned later via puppet)

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
 rm -rf target
 cp -a target-orig target
 target=target
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
 /etc/modules
do
 cp $target/$i backup
done

## Setting up default grub entry - 'Debian GNU/Linux, with Linux 2.6.*-xen-686 and XEN 4.0-*'
## Adding hypervisor option dom0_mem=384M

grub_file=$target/etc/default/grub
grub_entry=`grep "menuentry 'Debian GNU/Linux, with Linux 2\.6\..*-xen-686 and XEN 4.0-[0-9a-z]*'" $target/boot/grub/grub.cfg|tail -1|cut -d"'" -f2`
if [ -f $grub_file -a -n "$grub_entry" ]; then
 echo Configuring GRUB for "$grub_entry"
 ./strreplace.sh $grub_file "^GRUB_DEFAULT" "GRUB_DEFAULT='$grub_entry'"
 ./strreplace.sh $grub_file "^GRUB_CMDLINE_XEN" 'GRUB_CMDLINE_XEN="dom0_mem=384M"'
 # XXX there is no setting separately for xenkopt
 # XXX with nosmp md raid is not loading with hypervisor menuentry
 #echo 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX nosmp"' >>$grub_file
 test -z "$target" && update-grub
else
 echo Not configuring GRUB
fi

## Set hostname to fqdn
## Set xend-config.sxp: xend-relocation-hosts-allow to allow relocation from local domain (XXX broken)

hostname=`head -1 $target/etc/hostname`
if [ -n "$hostname" ]; then
ipaddr=`grep $hostname $target/etc/hosts|awk '{print $1}'`
hostfqdn=`grep $hostname $target/etc/hosts|awk '{print $2}'`
domain=`grep $hostname $target/etc/hosts|awk '{sub("^[^.]*\.","",$2); print $2}'`
# XXX f***ng backslash!
reloc_domain=`awk -v d="$domain" 'BEGIN{gsub("\.","\\.",d);gsub("\.","\\.",d);gsub("\.","\\.",d);print d; exit}'`
if [ -n "$domain" -a -n "$ipaddr" ]; then
 echo Configuring host/domainname stuff for $ipaddr $fqdn
 if [ "$hostname" = "$hostfqdn" ]; then
  echo Hostname configuration already ok
 else
  echo $hostfqdn >$target/etc/hostname
#  ./strreplace.sh xend-config.sxp "^\(xend-relocation-hosts-allow" "(xend-relocation-hosts-allow '^localhost$ ^gnt[0-9]+\\\\\\.$reloc_domain\$'"
  cp xend-config.sxp $target/etc/xen
 fi
else
 echo Not configuring host/domainname stuff
fi
fi

## Set default interface to be bridged, optionally with vlan (see postinst.conf)

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

## Set up CD-ROM repository: create /var/lib/cdimages, /media/sci

echo Setting up local CD-ROM repository
mkdir -p $target/var/lib/cdimages
mkdir -p $target/media/sci

cat <<EOF >>$target/etc/apt/apt.conf.d/99-sci
Acquire::cdrom::mount "/media/sci";
APT::CDROM::NoMount;
EOF

## Set up ganeti-instance-debootstrap source to local SCI-CD image

cat <<EOF >>$target/etc/default/ganeti-instance-debootstrap
MIRROR=file:/media/sci/
ARCH=i386
SUITE=squeeze
EXTRA_PKGS="linux-image-xen-686,libc6-xen"
EOF

## Add "xm sched-credit -d0 -w512" to /etc/rc.local
# equal priority of Dom0 make problems on the block devices
## Add sysfs tuning for better disk latency and to avoid kernel problems

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

# rise priority for dom0, alowing drbd to work fine
xm sched-credit -d0 -w512

# add disk tuning options to avoid (or reduce?) deadlocks
# gives better latency on heavy load
echo "0" >/proc/sys/vm/swappiness
echo "1" >/proc/sys/vm/overcommit_memory
echo "5" >/proc/sys/vm/dirty_background_ratio
echo "10" >/proc/sys/vm/dirty_ratio
echo "1000" >/proc/sys/vm/dirty_expire_centisecs

exit 0
EOF

chmod +x $target/etc/rc.local

## Add workaround for bnx2x NIC on HP Proliant and Blade servers
# https://bugzilla.redhat.com/show_bug.cgi?id=518531
echo "options bnx2x disable_tpa=1" >$target/etc/modprobe.d/sci.conf

## Set up symlinks /boot/vmlinuz-2.6-xenU, /boot/initrd-2.6-xenU

# we'll assume only one xen kernel at the moment of the installation
ln -s $target/boot/vmlinuz-2.6.*-xen-686 $target/boot/vmlinuz-2.6-xenU
ln -s $target/boot/initrd.img-2.6.*-xen-686 $target/boot/initrd.img-2.6-xenU

if [ ! -f /proc/mounts ]; then
	echo Warning: /proc is not mounted. Trying to fix.
	mkdir -p /proc
	mount /proc
	proc_mounted=1
fi

## Copy-in SCI-CD iso image to /var/lib/cdimages, mount to /media/sci, set up sources.list

dev=`grep '/cdrom' /proc/mounts|cut -d' ' -f1`

if [ -n "$dev" -a ! -e "$dev" ]; then
	echo ...Creating CD-ROM device $dev
	echo ... only stub here
fi
if [ -n "$dev" -a -e "$dev" ]; then
	echo ...Copying CD-ROM image
	dd if=$dev of=$target/var/lib/cdimages/sci.iso

	echo "/var/lib/cdimages/sci.iso /media/sci iso9660 loop 0 0" >>$target/etc/fstab

	echo ...Adding repository data
	mount /media/sci && (apt-cdrom -d=/media/sci add; umount /media/sci)
else
	echo Unable to find CD-ROM device
	echo "#/var/lib/cdimages/sci.iso /media/sci iso9660 loop 0 0" >>$target/etc/fstab
fi

test -n "$proc_mounted" && umount /proc

## Add ganeti hooks to attach SCI-CD to debootstrap-type instances just after startup as xvdc

mkdir -p $target/etc/ganeti/hooks
cp -r files/ganeti/hooks $target/etc/ganeti/

## Add ganeti-instance-debootstrap hooks for pygrub and SCI-CD

mkdir -p $target/etc/ganeti/instance-debootstrap/hooks
cp -r files/ganeti/instance-debootstrap/hooks/* $target/etc/ganeti/instance-debootstrap/hooks/

## Add ganeti-instance-debootstrap variant "sci"
mkdir -p $target/etc/ganeti/instance-debootstrap/variants
cp -r files/ganeti/instance-debootstrap/variants/* $target/etc/ganeti/instance-debootstrap/variants/
echo sci >>$target/etc/ganeti/instance-debootstrap/variants.list

## Add SCI deploing scripts
cp -r files/sci $target/etc/
cp files/sbin/* $target/usr/local/sbin/
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

# sources for approx apt cache server on sci
# all three together must be non empty, or nonexistent
APT_DEBIAN="debian http://ftp.debian.org/debian"
APT_SECURITY="security http://security.debian.org/debian-security"
APT_VOLATILE="volatile http://volatile.debian.org/debian-volatile"

# forwarders for DNS server on sci
# use syntax "1.2.3.4; 1.2.3.4;"
DNS_FORWARDERS=""

EOF
