#!/bin/sh
#chkconfig: 345 20 80
#description: Starts and stop the UGmon daemon
#
## /etc/init.d/ugmon.sh start|stop : to start and stop the UGMon daemon
##
## Bash shell for Linux
##
######################################################

BINFILE=/usr/share/ugmon/ugmon.pl
LOGFILE=/var/log/ugmon.log
PIDFILE=/var/run/ugmon.pid

test -x $BINFILE || exit 0

case "$1" in
  start)
    echo "Starting UGMon monitoring agent..."
    #DEBUG: use -debug to get some debug info in the logfile
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
    echo "Usage: /etc/init.d/ugmon {start|stop}"
    exit 2
    ;;
esac

exit 0
