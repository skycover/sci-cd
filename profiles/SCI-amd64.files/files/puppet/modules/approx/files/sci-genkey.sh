#!/bin/bash
export PATH=/usr/bin:/bin

HOMEDIR=/etc/sci/gpg

if [ -f $HOMEDIR/secring.gpg ]; then
  echo You already have keys is $HOMEDIR. Aborting.
  exit 1
fi
chmod 700 $HOMEDIR

# we need entropie for /dev/random, only keyboard, mouse and the disk
# controller driver call the /dev/random-functions 
find /usr -fstype nfs -prune -o -printf "%F:%h:%f\n" -type f -exec cp -v {} /dev/null \; >/dev/null 2>&1 &

gpg --homedir $HOMEDIR --no-options --batch --gen-key $HOMEDIR/sci-key-input
if [ $? -eq 0 ]; then
  gpg --homedir /etc/sci/gpg/ --export >$HOMEDIR/sci.pub
  echo Key exported to puppet
else
  echo GPG Key generation aborted
  exit 1
fi
