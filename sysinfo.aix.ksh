#!/bin/ksh
#################################################################
#
# Returns information about the system ,dusk usage, processes
# used by Dong monitoring agent
# author: Radu Dudici - Rubik Solutions 2010
# Korn shell for AIX
################################################################

echo "Sysinfo version 1.0 (aix), developed by Radu Dudici, Rubik Solutions 2010";

echo "BEGIN SYSINFO";
echo "Hostname: "$(hostname)
echo "Number of cores: "$(mpstat | grep lcpu | awk '{print $3}')
echo "OS Version: "$(uname -a)
echo "END SYSINFO";

echo "BEGIN VOLUMES";
#DEV MNT TOTAL FREE
df -m |grep -v "Filesystem" | awk '{ print $7"\t"$1"\t"$2"\t"$3}'
echo "END VOLUMES";

echo "BEGIN PROCESSES";
ps -e | grep -v "PID" | awk '{ print $4 }'
echo "END PROCESSES";


