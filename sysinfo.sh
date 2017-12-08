#!/bin/sh
#################################################################
#
# Returns information about the system ,dusk usage, processes
# used by Dong monitoring agent
# author: Radu Dudici - Rubik Solutions 2010
# Bash shell for Linux
################################################################

echo "Sysinfo version 1.0 (linux), developed by Radu Dudici, Rubik Solutions 2010";

echo "BEGIN SYSINFO";
echo "Hostname: "`hostname`
echo "Number of cores: "`cat /proc/cpuinfo | grep processor | wc -l`
echo "OS Version: "`uname -a`
echo "END SYSINFO";

echo "BEGIN VOLUMES";
#DEV MNT TOTAL FREE
df -mlP |grep -v "Filesystem" | awk '{ print $6"\t"$1"\t"$2"\t"$4}'
echo "END VOLUMES";

echo "BEGIN PROCESSES";
ps -e | grep -v "PID" | awk '{ print $4 }'
echo "END PROCESSES";


