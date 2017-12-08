#! /bin/sh
##
## /etc/init.d/ugmon.sh: start UGMon daemon
##
## Bash shell for Ubuntu/Linux
##
######################################################

BINFILE=/usr/share/ugmon/ugmon.pl
LOGFILE=/var/log/ugmon.log
PIDFILE=/var/run/ugmon.pid

test -x $BINFILE || exit 0

# Get lsb functions
. /lib/lsb/init-functions

case "$1" in
  start)
    log_daemon_msg "Starting UGMon monitoring agent..."
    #DEBUG: use -debug after -- to get some debug info in the logfile
    start-stop-daemon --start --pidfile $PIDFILE --exec $BINFILE -- -daemon -pid $PIDFILE -out $LOGFILE
    log_end_msg $?
    ;;
  restart|force-reload)
	# nothing to do
    ;;
  stop)
    log_daemon_msg "Stopping UGMon monitoring agent..."
    start-stop-daemon --stop --pidfile $PIDFILE
    log_end_msg $?
    rm -f $PIDFILE
    ;;
  status)
    exit 4
    ;;
  *)
    echo "Usage: /etc/init.d/ugmon {start|stop}"
    exit 2
    ;;
esac

exit 0
