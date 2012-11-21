#!/bin/bash
export PATH=/usr/bin:/bin

HOMEDIR=/etc/sci/gpg

# XXX not using -s here because the key generation may be long
if [ -f $HOMEDIR/secring.gpg ]; then
  echo You already have keys is $HOMEDIR. Aborting.
  exit 1
fi
chmod 700 $HOMEDIR

# we need entropie for /dev/random, only keyboard, mouse and the disk
# controller driver call the /dev/random-functions 
# ...but sha256sum too:
# http://aaronhawley.livejournal.com/10807.html
# but computers are too fast nowdays...
(while [ ! -s $HOMEDIR/secring.gpg ]; do
  if [ -n "$ENTROPY" ]; then
    if ps -ef | grep find | awk '{ print $2 }' | grep -q ${ENTROPY}; then 
      sleep 60
    else
      echo restarting random generator
      find / -xdev -type f -exec sha256sum {} >/dev/null \; 2>&1 &
      export ENTROPY=$!
    fi
  else
      # XXX ugly? hmmm...
      find / -xdev -type f -exec sha256sum {} >/dev/null \; 2>&1 &
      export ENTROPY=$!
  fi
done
  ps -ef | grep find | awk '{ print $2 }' | grep -q ${ENTROPY} && kill ${ENTROPY}
  killall -q sha256sum
) &

gpg --homedir $HOMEDIR --no-options --batch --gen-key $HOMEDIR/sci-key-input


if [ $? -eq 0 ]; then
  gpg --homedir /etc/sci/gpg/ --export >$HOMEDIR/sci.pub
  echo Key exported to puppet
else
  echo GPG Key generation aborted
  exit 1
fi

