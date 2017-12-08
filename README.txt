#####################################################
##                                                 ##
##                    UGMON                        ##
##                                                 ##
##                                                 ##
## Authors:	Uffe Gavnholt, Rubik Solutions         ##
##              Radu Dudici, Rubik Solutions       ##
##                                                 ##
## Version:	1.13   (dec-2010)                      ##
##              for Win, Linux, HPUX, AIX          ##
##                                                 ##
#####################################################

ABOUT:
========

This is a small collection of scripts designed to gether information about the OS and OS's events. The information is then sent (via SNMP traps) to a manager that performs a general monitoring. The application is platform independent and so it can be run on Windows, Linux or Unix machines.

INSTALLATION:
=============

On Windows:
-----------

Run (as Administrator) the provided installation application that will install the scripts, the necessary tools (Perl & modules) in "{SD}:\UGMon" and install a service called UGMon. The service needs to be started manually afterwards (net start UGMon).

NOTE: Before starting the script be sure to edit the config file Local_Monitoring.conf

The default comand in linux is:
c:\UGMon\perl\bin\perl.exe c:\UGMon\ugmon.pl -pid c:\UGMon\ugmon.pid >c:\UGMon\ugmon.log

The Windows service is running ugmon.bat so the command parameters of ugmon.pl may be changed and customized here if necessary (ex add debug "-debug").

Start or stop the service from the console or using net command:
net start UGMon
net stop UGMon

On Linux:
----------

Run (as root) the installation script "install.sh" that will install the files (in /usr/share/ugmon), the daemon startup script (in /etc/init.d), create links to config files in /etc/ugmon/. The logfile is set to /var/log/ugmon.log. The pid file is set to /var/run/ugmon.pid

The default command in linux is:
/usr/share/ugmon.pl -- -daemon -pid /var/run/ugmon.pid -out /var/log/ugmon.log

The script that starts the daemon is /etc/init.d/ugmon.sh so here the command line parameters may be changed and customized (ex add debug info "-debug" or change the log and pid paths).

Start or stop the daemon by commands:
/etc/init.d/ugmon.sh start
/etc/init.d/ugmon.sh stop

NOTE: Before starting the script be sure to edit the config file Local_Monitoring.conf

USAGE:
========

ugmon.pl
--------
The main script is ugmon.pl. It can be used as a service/daemon background application or as tool to perform other tasks (ex: issue maintenance start event)

Usage 1 as service/daemon:

ugmon.pl [-debug] [-out filename | -lout] [-pid filename | -lpid] [-daemon]
      -debug : sets debug and extra verbous mode
      -out filename : redirects output to a file (used if the default redirection ">" is not possible)
      -pid filename : sets the pid file (used to stop the process in win and linux when running as service/daemon). Required if it needs to rung continuously.
      -lout : creates a local file (ugmon.log) to redirect output (in the script's folder)
      -lpid : creates a local pid file (ugmon.pid) (in the script's folder)
      -daemon : daemonize (fork and stay running). Required for unix like systems.
      -? | -h : display help

Usage 2 to inform the manager about starting a maintenance session:
ugmon.pl <-startMaint> <user> <description> <durationMins>
      -startMaint : report the manger about entering the maintenance stage
      user : the username
      description : description text to be sent
      durationMins : duration in minutes of the maintenance

If the script is run without arguments it will perform a single check - this can be used with scheduled tasks - however the script will not remember in this way the status of the events.

If the -pid (or -lpid) argument is used the script will run in a continuous loop until the pid file is deleted (works in Win and unix/linux). On unix/linux the script can be terminated also by sending the TERM signal (kill -s 15 <pid>)

Usage example:

The following example will start the script in a continuous loop until the pid file is deleted (both Win and linux) or until sending a TERM signal. It wil lalso print a lot of debug info:
ugmon.pl -debug -pid ugmon.pid

The following example will run the script with a single check and output everything in a file
ugmon.pl -debug -out ugmon.log

The following example will daemonize the script in unix/linux (fork and keep it running in background), have the output redirected to a file and create a pid file to keep it running. Terminate it by sending the TERM signal or deleting the pid file:
ugmon.pl -debug -daemon -pid ugmon.pid -out ugmon.log

ugMonMaint.exe
--------------

This is a small Windows application to run ugmon.pl with -startMain argument and the other parameters to inform the manager that the node will start a maintenance session and so the alarms are not to be considered.

In unix/linux the user will call ugmon.pl with the -startMain argument (and the rest of parameters) manually.

CONFIG:
========

The configuration file provides some run time parameters as well as describe the objects to be monitored. There is a global configuration file Monitoring.conf that SHOULD NOT be changed and a local configuration file Local_Monitoring.conf that can be edited to add new or overwrite setting from the global.

Please see the global configuration file for details of syntax and format (Monitoring.conf).


PACKAGE DETAILS:
=================

For Windows:

ugmon.pl - This is the main script that collects the data and sends the alarms
ugmon.bat - a batch file to start the perl script for Windows. This is automatically created by the installation program at deployment.
ugmonmaint.bat - a batch file to start the perl script to send the maintenance message to the manager. This is automatically created by the installation program at deployment.
ugMonMaint.exe - a GUI to send the maintenance message to the manager. It uses ugmonmaint.bat.
createbat.bat - used by the installation program to create ugmon.bat and ugmonmaint.bat with the right paths
Monitoring.conf - This is the main/global configuration file. Do not edit this one
Local_Monitoring.cong - This is a local configuration file in the same format as Monitoring.conf that will add/overwrite settings from the master
ServiceStart.exe - this is a small application, that installs and launch a scripts as windows services, it can install services, and remove them as well.
startservice.bat - used by the installer to starts the service after installation
Sysinfo.exe - This is the script that collects the service, process and drive information on windows
perl - the folder with Perl binaries (including SNMP and Proc::Daemon) - used only in Windows


General sources:

Net-SNMP-v6.0.0 - this is the perl module to send snmp trap. (included already in folder "perl" for Windows). Is gets installed on linux.
SNMP_Session-1.13 - the old SNMP library used up to version 1.6
Proc-Daemon-0.03 - this is the PROC::DAEMON perl module for ugmonizing the script in unix/linux. (included already in folder "perl" for Windows). Is gets installed on linux.
setup.iss - the InnoSetup script to create an installation package. Get Inno Setup from http://www.jrsoftware.org/
README.txt - this readme file
changelog.txt - logfile with changes on each version
winrelease - the folder where the installation package is created for Windows
unix - the folder where unix/linux files are located


For Linux/Unix (inside folder unix/):

ugmon.pl - This is the main script that collects the data and sends the alarms
install.sh - the installation script for linux
install.ksh - the installation script for AIX, HPUX
sysinfo.sh - This is the script that collects the service, process and drive information on linux
sysinfo.aix.ksh - This is the script that collects the service, process and drive information on aix
sysinfo.hpux.ksh - This is the script that collects the service, process and drive information on hpux
dugmon.sh - a shell script to start the perl script as a daemon in Linux
ugmon.ksh - a shell script to start the perl script as a daemon in HPUX, AIX
ugmon.ubuntu.sh - a shell script to start the perl script as a daemon in Ubuntu Linux (NOT USED)
Monitoring.conf - This is the main/global configuration file. Do not edit this one
Local_Monitoring.cong - This is a local configuration file in the same format as Monitoring.conf that will add/overwrite settings from the master




