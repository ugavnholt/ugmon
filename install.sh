#!/bin/sh
##
## Installation program for UGMon for linux
##
############################################

DESTINATION="/usr/share/ugmon"
LOGFILE="/var/log/ugmon.log"
PIDFILE="/var/run/ugmon.pid"
STARTUPFOLDER="/etc/init.d"
CFGFOLDER="/etc/ugmon"


if [ $# -eq 0 ]; then

	echo "Installation/Uninstallation program for UGMon"
	echo "Usage"
	echo "./install.sh [-install] [-uninstall]"
	exit
fi

if [ "$1" = "-install" ]; then
	echo "This will install UGMon daemon..."
#	echo "[PRESS ENTER] to continue or Ctrl+C to stop."
#	read
	echo "Install Proc::Daemon package ..."
	echo "[PRESS ENTER]"
#	read
	cd Proc-Daemon-0.03
	perl Makefile.PL
	make
	make test
	make install
	cd ..
	echo "PROC::DAEMON installation ... DONE"
	echo ""

	echo "Install SNMP Package ..."
	#echo "[PRESS ENTER]"
	#read
	cd Net-SNMP-v6.0.0
	perl Makefile.PL
	make test
	make install
	cd ..
	echo "Net::SNMP installation ... DONE"
	echo ""


	echo "Copy script's files to "$DESTINATION
	echo "Copy startup script to "$STARTUPFOLDER
	echo "Create links to script's config files in "$CFGFOLDER
	#echo "[PRESS ENTER]"
	#read
	mkdir -p $DESTINATION
	cp README.txt $DESTINATION/
	cp ugmon.pl $DESTINATION/
	cp sysinfo.* $DESTINATION/
	cp Monitoring.conf $DESTINATION/
	cp Local_Monitoring.conf $DESTINATION/

	mkdir -p $CFGFOLDER/
	ln -s $DESTINATION/Monitoring.conf $CFGFOLDER/Monitoring.conf
	ln -s $DESTINATION/Local_Monitoring.conf $CFGFOLDER/Local_Monitoring.conf

	cp ugmon.sh $STARTUPFOLDER/

	echo "UGMon succesfully installed."
	echo "Please edit the config file $CFGFOLDER/Local_Monitoring.conf then start the service: $STARTUPFOLDER/ugmon.sh start"
	echo "Do not forget to stop the service before uninstalling: $STARTUPFOLDER/ugmon.sh stop"
	chmod 755 /usr/share/ugmon/ugmon.pl
	chmod 755 /usr/share/ugmon/sysinfo.sh
	chmod 755 /etc/init.d/ugmon.sh
	mv /etc/init.d/ugmon.sh /etc/init.d/UGMon
	chkconfig --add UGMon
	service UGMon start
	SERVER=`uname -n`
	echo "UGMon service defined and started on server $SERVER..."
fi

if [ "$1" = "-uninstall" ]; then
	echo "This will uninstall ugmon daemon ..."
	echo "[PRESS ENTER] to continue or Ctr+C to stop"
	read

	echo "Stop ugmon daemon..."
	$STARTUPFOLDER/ugmon.sh stop

	echo "Remove files..."
	rm $STARTUPFOLDER/ugmon.sh
	rm -r $DESTINATION
	rm -r $CFGFOLDER
	rm $LOGFILE
	rm $PIDFILE

	echo "UGMon successfully uninstalled."
fi


