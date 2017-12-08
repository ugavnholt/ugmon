#!/usr/bin/ksh
##
## /sbin/init.d/ugmon.sh: start UGMon daemon
##
## Korn shell for AIX and HPUX
##
######################################################

BINFILE=/usr/share/ugmon/ugmon.pl
LOGFILE=/var/adm/ugmon.log
PIDFILE=/var/run/ugmon.pid

test -x $BINFILE || exit 0

case "$1" in
  start)
    echo "Starting UGMon monitoring agent..."
    #DEBUG: use -debug after -- to get some debug info in the logfile
    $BINFILE -debug -daemon -pid $PIDFILE -out $LOGFILE
    ;;
  restart|force-reload)
	# nothing to do
    ;;
  stop)
    echo "Stopping UGMon monitoring agent..."
    if [ ! -f $PIDFILE ]
    then
       echo "No PIDFILE ($PIDFILE) found."
       exit 1
    fi
    PID=$(cat $PIDFILE); kill -s 15 $PID
    rm -f $PIDFILE
    ;;
  status)
    exit 4
    ;;
  *)
    echo "Usage: /sbin/init.d/ugmon {start|stop}"
    exit 2
    ;;
esac

exit 0
