#!/bin/bash
# needed uuencode/decode (sharutils)
# need cdbs to assemble chose-partman-recipe udeb
#

usage(){
  cat <<EOF >&2
build.sh [-p PROFILE] -d DISKS|all [-v yes|no] -l [1|10|none]
  -p PROFILE  - default: SCI-amd64
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

if [ ! -x /usr/bin/uuencode ]; then
 echo Please install sharutils
 exit 1
fi

profile=SCI-amd64
partvar=no
partlvm=yes

while getopts "hp:d:v:l:" opt; do
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

if [ -z "$disks" ]; then
  cp profiles/default.preseed.$profile.in profiles/default.preseed
  echo "#no options" >src/chose-partman-recipe/manual.preseed
  ./partgen.sh -d 1 -l 1 >src/chose-partman-recipe/d1l1.preseed
  ./partgen.sh -d 1 -l none >src/chose-partman-recipe/d1lnone.preseed
  ./partgen.sh -d 2 -l 1 >src/chose-partman-recipe/d2l1.preseed
  ./partgen.sh -d 2 -l none >src/chose-partman-recipe/d2lnone.preseed
  ./partgen.sh -d 4 -l 10 >src/chose-partman-recipe/d4l10.preseed
  ./partgen.sh -d 6 -l 10 >src/chose-partman-recipe/d6l10.preseed
  ./partgen.sh -d 8 -l 10 >src/chose-partman-recipe/d8l10.preseed
  (cd src/chose-partman-recipe; dpkg-buildpackage)
  mkdir -p local
  cp src/chose-partman-recipe*.udeb local
  test -d tmp/mirror && (cd tmp/mirror; reprepro remove squeeze chose-partman-recipe)
else
  awk '//{print}/#### INCLUDE PARTMAN ####/{exit}' profiles/default.preseed.$profile.in >profiles/default.preseed
  ./partgen.sh -d $disks -v $partvar -l $partlvm >>profiles/default.preseed
  echo "d-i chose-partman-recipe/recipe select Preseed" >>profiles/default.preseed
  awk '//{if(s)print}/#### INCLUDE PARTMAN ####/{print "#### PARTMAN INCLUDED ####"; s=1}' profiles/default.preseed.$profile.in >>profiles/default.preseed
fi

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
