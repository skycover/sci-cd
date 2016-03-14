#! /bin/sh
### BEGIN INIT INFO
# Provides:          drbd-sync-rate
# Required-Start:    $syslog drbd
# Required-Stop:     $syslog drbd
# Should-Start:      $network
# Should-Stop:       $network
# X-Start-Before:    network
# X-Stop-After:      network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: runs script for drbd sync rate adjusting
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/local/sbin/drbd-sync-rate-daemon
NAME=drbd-sync-rate
PIDFILE=/var/run/$NAME.pid
DESC="Wan Failover Script"

unset TMPDIR

test -x $DAEMON || exit 0

. /lib/lsb/init-functions

# Get the timezone set.
if [ -z "$TZ" -a -e /etc/timezone ]; then
    TZ=`cat /etc/timezone`
    export TZ
fi

case "$1" in
  start)
	log_begin_msg "Starting $DESC: $NAME"

	start-stop-daemon --start -b --quiet --pidfile "$PIDFILE" --exec "$DAEMON" && success=1
	log_end_msg $?
	;;
  stop)
	log_begin_msg "Stopping $DESC: $NAME"
	kill `cat $PIDFILE`
	log_end_msg $?
	;;
  reload|force-reload)
        echo "Error: argument '$1' not supported" >&2
        exit 3
       ;;
  restart)
        echo "Error: argument '$1' not supported" >&2
        exit 3
	;;
  status)
	echo -n "Status of $DESC: "
	if [ ! -r "$PIDFILE" ]; then
		echo "$NAME is not running."
		exit 3
	fi
	if read pid < "$PIDFILE" && ps -p "$pid" > /dev/null 2>&1; then
		echo "$NAME is running."
		exit 0
	else
		echo "$NAME is not running but $PIDFILE exists."
		exit 1
	fi
	;;
  *)
	N=/etc/init.d/${0##*/}
	echo "Usage: $N {start|stop|status}" >&2
	exit 1
	;;
esac

exit 0
