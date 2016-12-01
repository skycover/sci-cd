#!/bin/bash
# this is the post-install script
# the newly-installed system is not yet booted, but chrooted at the moment of execution

set -x

VERSION=2.3

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
 ./strreplace.sh $grub_file "^GRUB_CMDLINE_XEN" 'GRUB_CMDLINE_XEN="dom0_mem=1536M"'
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
base_name=`echo $hostname|sed -E 's/^([^.]*[^0-9])[0-9]+\.?.*/\1/'`
ipaddr=`grep $hostname $target/etc/hosts|awk '{print $1}'`
hostfqdn=`grep $hostname $target/etc/hosts|awk '{print $2}'`
domain=`grep $hostname $target/etc/hosts|awk '{sub("^[^.]*\.","",$2); print $2}'`
#reloc_domain=`awk -v d="$domain" 'BEGIN{gsub("[.]","\\\\\\\\\\\\\\\\.",d);print d; exit}'`
if [ -n "$domain" -a -n "$ipaddr" ]; then
 echo Configuring host/domainname stuff for $ipaddr $fqdn
 if [ "$hostname" = "$hostfqdn" ]; then
  echo Hostname configuration already ok
 else
  nodenum=`echo $hostname|sed 's/^[^0-9]*\([0-9][0-9]*\)$/\1/g'`
  if [ -z $nodenum -o $nodenum -lt 0 -o $nodenum -gt 90]; then
   echo "Host name must ends with number between 1 and 90"|tee -a $target/etc/should-reinstall
  fi
  echo $hostfqdn >$target/etc/hostname
#  ./strreplace.sh xend-config.sxp "^\(xend-relocation-hosts-allow" "(xend-relocation-hosts-allow '^localhost$ ^$base_name[0-9]+\\\\\\\\.$reloc_domain\$')"
  # copy template for xend-config.sxp - it will be tuned in sci-setup
  mkdir -p $target/etc/xen
  cp xend-config.sxp $target/etc/xen
 fi
else
 echo Not configuring host/domainname stuff
fi
fi

## Assign supersede parameters for node's dhcp
dns=10.101.200.20 # sci
./strreplace.sh $target/etc/dhcp/dhclient.conf "^#supersede domain-name" "supersede domain-name $domain\;\nsupersede domain-name-servers $dns\;"

## Set default interface to be bridged, optionally with vlan (see postinst.conf)

echo Configuring interfaces
ifs=$target/etc/network/interfaces
iface=`awk '/^iface /{if($2 != "lo"){print $2;exit}}' $ifs`
if grep "$iface.*inet.*dhcp" $ifs; then
  echo "LAN interface must be static"|tee -a $target/etc/should-reinstall
fi

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
auto lan
iface lan inet static
EOF

awk '/^[ \t]*(address|netmask|network|broadcast|gateway)/' $ifs >>interfaces
cat <<EOF >>interfaces
        bridge_ports $xenif
        bridge_stp off
        bridge_fd 0

EOF

## Add example of additional interfaces

cat <<EOF >>interfaces

# The exmample for static IP on WAN interface
# on the second ethernet card

#auto wan
#iface wan inet static
#        address 192.168.X.X
#        netmask 255.255.255.0
#        network 192.168.X.0
#        broadcast 192.168.X.255
#        gateway 192.168.X.1
#        bridge_ports eth1
#        bridge_stp off
#        bridge_fd 0

# The example of dhcp-configured WAN interface
# on the second ethernet card

#auto wan
#iface wan inet dhcp
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
#auto VLAN_NAME
#iface VLAN_NAME inet manual
#        up brctl addbr VLAN_NAME
#        up brctl addif VLAN_NAME eth0.8
#        up brctl stp VLAN_NAME off
#        up ifconfig VLAN_NAME up
#        down ifconfig VLAN_NAME down
#        down brctl delbr VLAN_NAME
EOF

cat interfaces >$ifs.tmp

## Set up module loading (drbd, 8021q, loop)

echo Setting up modules
echo options drbd minor_count=128 usermode_helper=/bin/true disable_sendpage=1 >>$target/etc/modprobe.d/drbd.conf
echo options loop max_loop=64 >>$target/etc/modprobe.d/local-loop.conf
echo drbd >>$target/etc/modules
echo 8021q >>$target/etc/modules

## Allow plugins and facts syncing for puppet
echo Editing puppet.conf
sed -i '/\[main\]/ a\pluginsync = true' $target/etc/puppet/puppet.conf

## Set DRBD resync speed auto adjustment
cp files/drbd-sync-rate.init.d $target/etc/init.d/drbd-sync-rate
update-rc.d drbd-sync-rate defaults >/dev/null

## Enable puppet to start

echo Setting up defaults
./strreplace.sh $target/etc/default/puppet "^START=" "START=yes"

## Disable xendomains saving options

./strreplace.sh $target/etc/default/xendomains "^XENDOMAINS_SAVE" 'XENDOMAINS_SAVE=""'

## Enable smartd to start

./strreplace.sh $target/etc/default/smartmontools "^#start_smartd=yes" "start_smartd=yes"

## Tune temperature warning on smartd

./strreplace.sh $target/etc/smartd.conf "^DEVICESCAN" "DEVICESCAN -d removable -n standby -m root -R 194 -R 231 -I 9 -W 5,50,55 -M exec /usr/share/smartmontools/smartd-runner"

## Remove /media/usb0 mountpoint from fstab as we using usbmount helper

sed -i '/\/media\/usb0/d' $target/etc/fstab

## Add flush option for USB-flash mounted with vfat

./strreplace.sh $target/etc/usbmount/usbmount.conf "^FS_MOUNTOPTIONS" 'FS_MOUNTOPTIONS="-fstype=vfat,flush"'

## Set localized console and keyboard

cp files/default/* $target/etc/default/

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

# If you use hardware raid or external FC/Infiniband storage, you prorably would rather use noop scheduler instead of deadline

# rise priority for dom0, alowing drbd to work fine
xm sched-credit -d0 -w512

modprobe sg
disks=\`sg_map -i|awk '{print substr(\$2, length(\$2))}'\`
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
vm.overcommit_memory = 1
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.dirty_expire_centisecs = 1000
EOF

## Add workaround for bnx2x NIC on HP Proliant and Blade servers
# https://bugzilla.redhat.com/show_bug.cgi?id=518531
## Disable autosuspend for usb devices which cause some keyboards to hang
# http://debian.2.n7.nabble.com/Bug-689368-linux-image-3-5-trunk-amd64-Mouse-and-keyboard-freeze-on-Ivy-Bridge-platform-td2508855.html
cat <<EOF  >$target/etc/modprobe.d/sci.conf
options bnx2x disable_tpa=1
options usbcore autosuspend=-1
EOF

## Set up symlinks /boot/vmlinuz-xenU, /boot/initrd-xenU

# we'll assume only one xen kernel at the moment of the installation
ln -s $target/boot/vmlinuz-*-amd64 $target/boot/vmlinuz-xenU
ln -s $target/boot/initrd.img-*-amd64 $target/boot/initrd.img-xenU

## Set up symlink /usr/lib/xen for quemu-dm (workaround)
ln -s $target/usr/lib/xen-4.1 $target/usr/lib/xen

if [ ! -f /proc/mounts ]; then
	echo Warning: /proc is not mounted. Trying to fix.
	mkdir -p /proc
	mount /proc
	proc_mounted=1
fi

# Mount /stuff if we detect unmounted xenvg/system-stuff
mkdir -p $target/stuff
grep -q /stuff /proc/mounts || test -b $target/dev/xenvg/system-stuff && test -d $target/stuff && grep -q /stuff $target/etc/fstab && mount $target/stuff

# Place commented-out template for /stuff if no one
grep -q /stuff $target/etc/fstab || echo "#/dev/xenvg/system-stuff /stuff ext4 errors=remount-ro 0 0" >>$target/etc/fstab

## Set up CD-ROM repository: create /stuff/cdimages, /media/sci

echo Setting up local CD-ROM repository
mkdir -p $target/stuff/cdimages
mkdir -p $target/media/sci

cat <<EOF >>$target/etc/apt/apt.conf.d/99-sci
Acquire::cdrom::mount "/media/sci";
APT::CDROM::NoMount;
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

## set sci apt sources
cp files/apt/sci-dev.list $target/root
cp files/apt/apt.pub $target/etc/apt/sci-dev.pub
apt-key add $target/etc/apt/sci-dev.pub


## Symlink gplpv.iso with signed windows drivers to /stuff/cdimages
# this file can also be found in /media/sci/simple-cdd/gplpv.iso
ln -s /media/sci/simple-cdd/gplpv.iso $target/stuff/cdimages/gplpv.iso

## Link /var/lib/ganeti/export to /stuff/export

mkdir -p $target/var/lib/ganeti/export
mkdir -p $target/stuff/export
echo "/stuff/export   /var/lib/ganeti/export ext4 bind 0 0" >> $target/etc/fstab

test -n "$proc_mounted" && umount /proc
umount /stuff

## Add ganeti hooks if any

mkdir -p $target/etc/ganeti/hooks
cp -r files/ganeti/hooks $target/etc/ganeti/

## Set proper sci instance name for stages.conf
#sed -i "s/sci/sci.$domain/" $target/etc/ganeti/stages.conf

## Add custom scripts to local/sbin
cp files/sbin/* $target/usr/local/sbin/

## Add nut configs
cp files/nut/* $target/etc/nut
chown root:nut $target/etc/nut/*
chmod 640 $target/etc/nut/*
echo "%nut    ALL=NOPASSWD: /usr/local/sbin/gnt-node-shutdown.sh" >> $target/etc/sudoers
update-rc.d nut-client remove

## Write motd
cat <<EOF >$target/etc/motd

SkyCover Infrastructure high availability cluster node, ver. $VERSION
For more information see http://www.skycover.ru

EOF

## Set chrony reboot if there is no sources

echo 'PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin' >> $target/etc/cron.d/chrony
echo '*/10 * * * *	root	chronyc sourcestats|grep -q "^210 Number of sources = 0" && service chrony restart' >> $target/etc/cron.d/chrony

## Filling SCI configuration template

mkdir $target/etc/sci
cat <<EOF >$target/etc/sci/sci.conf
# This is the SCI-CD cluster setup parameters
# Fill the values and execute "sci-setup cluster"

# The hostname to represent the cluster (without a domain part).
# It MUST be different from any node's hostnames
CLUSTER_NAME=

# The IP address corresponding to CLUSTER_NAME.
# It MUST be different from any node's IP.
# You should not up this IP address manualy - it will be automatically
# activated as an interface alias on the current master node
# We suggest to assign this address in the LAN (if LAN segment is present)
CLUSTER_IP=

# The first (master) node data
NODE1_NAME=
NODE1_IP=10.101.200.11

# Optional separate IP for SAN (should be configured and up;
# ganeti node will be configured with -s option)
NODE1_SAN_IP=
# Optional separate IP for LAN (should be configured and up)
NODE1_LAN_IP=

# Mandatory IP for virtual service machine "sci" in the backbone segment
SCI_IP=10.101.200.2
# Optional additional IP for virtual service machine "sci" in the LAN segment.
# If NODE1_LAN_IP is set, then you probably wish to set this too.
# (you should not to pre-configure this IP on the node)
SCI_LAN_IP=
# Optional parameters if NODE1_LAN_IP not configured
# If not set, it will be omited in instance's interface config
SCI_LAN_NETMASK=
SCI_LAN_GATEWAY=

# Single mode. The cluster will be set up without second node, in non redundant mode
# Uncomment to enable single mode
#SINGLE_MODE=yes


# The second node data
NODE2_NAME=
NODE2_IP=
NODE2_SAN_IP=
NODE2_LAN_IP=

# Network interface for CLUSTER_IP
# (if set, this interface will be passed to "gnt-cluser init --master-netdev")
# Autodetect if NODE1_LAN_IP is set and CLUSTER_IP matches LAN network
MASTER_NETDEV=
MASTER_NETMASK=

# Network interface to bind to virtual machies by default
# (if set, this interface will be passed to
# "gnt-cluster init --nic-parameters link=")
# Autodetect if NODE1_LAN_IP or MASTER_NETDEV are set
LAN_NETDEV=

# reserved volume names are ignored by Ganety and may be used for any needs
# (comma separated)
RESERVED_VOLS="xenvg/system-.*"

# sources for approx apt cache server on sci
# all two together must be non empty, or nonexistent
APT_DEBIAN="debian http://ftp.debian.org/debian/"
APT_SECURITY="security http://security.debian.org/"

# forwarders for DNS server on sci
# use syntax "1.2.3.4; 1.2.3.4;"
DNS_FORWARDERS=""

# Locale and timezone for cluster
# It will be set via puppet
TIMEZONE="Europe/Moscow"
#TIMEZONE="US/Pacific"
LOCALE="ru_RU.UTF-8"
#LOCALE="en_US.UTF-8"

EOF

# Write installed version information
echo $VERSION >$target/etc/sci/sci.version
