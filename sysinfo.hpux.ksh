#!/bin/ksh
#################################################################
#
# Returns information about the system ,dusk usage, processes
# used by Dong monitoring agent
# author: Radu Dudici - Rubik Solutions 2010
# Korn shell for HPUX
################################################################

echo "Sysinfo version 1.0 (hpux), developed by Radu Dudici, Rubik Solutions 2010";

echo "BEGIN SYSINFO";
echo "Hostname: "$(hostname)
echo "Number of cores: "$(vparstatus -p sandbox1 | awk '/sandbox1/{print $3}' | head -2 | grep -v Dyn)
echo "OS Version: "$(uname -a)
echo "END SYSINFO";

echo "BEGIN VOLUMES";
#DEV MNT TOTAL FREE
bdf | grep -v "Filesystem"  | while read FS TOT USED AVAIL PERCENT MNT
do
 if [ "$TOT" = "" ]
  then
   read TOT USED AVAIL PERCENT MNT
  fi
 echo $FS $TOT $USED $AVAIL $PERCENT $MNT
done | awk '{ print $6"\t"$1"\t"$2"\t"$4}'
echo "END VOLUMES";

echo "BEGIN PROCESSES";
ps -e | grep -v "PID" | awk '{ print $4 }'
echo "END PROCESSES";


