#!/bin/sh
# needed uuencode/decode (sharutils)
#
profile="$1"
test -z "$profile" && profile=default

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
