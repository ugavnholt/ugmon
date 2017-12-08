#!/usr/bin/perl -w
##
## UGMON - script to collect and report predefined OS events
##
## Authors:	Uffe Gavnholt, Rubik Solutions,
##              Radu Dudici, Rubik Solutions
## Version:	1.13 (for Win, Linux, AIX; HPUX)
##
## Usage 1: ugmon.pl [-debug] [-out filename | -lout] [-pid filename | -lpid] [-daemon]
## -debug : sets debug and extra verbous mode
## -out filename : redirects output (used if the default redirection ">" is not possible)
## -pid filename : sets the pid file (used to stop the process in win and linux when running as service/daemon)
## -lout : create a local file to redirect output (in the script's folder)
## -lpid : create a local pid file (in the script's folder)
## -daemon : daemonize (fork and stay running for unix like sys)
## -h | -? : some help
##
## Usage 2: ugmon.pl <-startMaint> <user> <description> <durationMins>
## -startMaint : report the manger about entering the maintenance stage
## user : the username
## description : description text to be sent
## durationMins : duration in minutes of the maintenance
##
##
## changes on 1.13
##				- added message group and severity handling
##				- added date/time on debug/error output
##
## changes on 1.12b,c,d,e,f
##              - the bat file to start the script removes the existing Perl path not to conflict with other perl installation
##              - order of the status is now "current" then "normal"
##              - fixed the $OS/$PLATFORM issue
##              - sysinfo.exe compiled for Win2000 also
##              - createbat.bat removes the quotes from the input parameter (for compatibility with W2k)
##
## changes on 1.12
##		- adding OS flavor from sysinfo and app ver into the hello & goodby message
##		- the order of params for SendProcessFailureEvent and SendServiceFailureEvent are "actual state" then "normal/desired state"
##
## changes on 1.11
##		- the OS platform is also sent via the SNMP trap
## 		
## changes on 1.10
##      - fix the storage reporting to consider also free_space=0
##      - the Local_Monitoring.conf is not deleted upon uninst
## 
## changes on 1.9
##		- fixed the comparison. == for integers, eq for strings
## 
## NOTE: "aclient" version: starts and stops aclient service upon install (in startservice.bat)
## 
## changes on 1.8
##       - changed/fixed so that "Hostname of physical node" is not used. Use only "Hostname"
## 
## changes on 1.7
##       - SNMP traps are waiting for confirmation and resend if not received by the manager
##       - send snmp traps also when the states are back to normal
## 
## changes on 1.6
##       - Every service with state!=4 is considered NOTRUNNING
## 
## changes on 1.5
##       - added SendGoodbyEvent (for unregistration, OID:1,3,6,1,4,1,15282,10,0,9) upon uninstallation as oposed to SendHelloEvent (for registration)
##       - the uninstallation will delete the ServiceStart registry key so a new installation in a different path will work
## 
## changes on 1.4
##       - sleep is divided in slots of 2 sec while checking for pidfile (also the proc is killed if it does not exit nice in 5 sec)
##       - c:\Program Files is the default path for installation
##       - if volume label is empty the volume id is sent instead
## 
## changes on 1.3
##       - fix bug: chomp replaced with trim
## 
## changes on 1.2 (from 1.1)
##		- fix bug in SendHelloEvent and SendErrorEvent reagarding the OID
## 		- fix: added "use SNMP_Session"
##      - enable SNMP sending
## 
## version 1.1
##		- implementation ready
##		- running test performed
##		- SNMP sending disabled
##
###########################################################################################################

# Forward declarations


# SendHelloEvent is used whenever the agent initializes to notify the manager of the system it is running on
# arg0 = snmp session
# arg1 = FQN of the host on which the agent runs (physical node name)
# arg2 = platform <WIN|UX>
# arg3 = OS version
# arg4 = UGMon version
sub SendHelloEvent($$$$$);

# SendGoodbyEvent is used whenever the agent is uninstalling to notify the manager of the system it will stop
# arg0 = snmp session
# arg1 = FQN of the host on which the agent runs (physical node name)
# arg2 = platform <WIN|UX>
# arg3 = OS version
# arg4 = UGMon version
sub SendGoodbyEvent($$$$$);

# SendDiskMetric is used to send a value of a measured disk utilization to the proxy agent
# This event is also used as a keep-alive for the agent
# arg0 = SNMP session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = name of the volume to which the value belongs
# arg4 = total capacity in megabytes
# arg5 = number of free megabytes on the volume
sub SendDiskMetricEvent($$$$$$);

# SendProcessFailureEvent is used to send a notification about a process that does not match a rule in the configuration file
# arg0 = SNMP session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = name of the process
# arg4 = the actual state of the process (RUNNING, NOTRUNNING)
# arg5 = the desired state of the process (RUNNING, NOTRUNNING)
# arg6 = message group
# arg7 = severity
sub SendProcessFailureEvent($$$$$$$$);

# SendServiceFailureEvent is used to send a notification about a services that does not match a rule in the configuration file
# arg0 = the snmp session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = name of the service
# arg4 = actual state of the service (RUNNING, NOTRUNNING)
# arg5 = desired state of the service (RUNNING, NOTRUNNING)
# arg6 = display label of the service
# arg7 = message group
# arg8 = severity
sub SendServiceFailureEvent($$$$$$$$$);

# SendClusterStateEvent is used to send a notification whenever a state change is detected for a cluster resource group
# arg0 = snmp session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = cluster resource group name
# arg4 = cluster name
# arg5 = cluster group (up, down, partup)
sub SendClusterStateEvent($$$$$$);

# SendErrorEvent is used to send a generic text message and severity, to describe the operation of ugmon
# arg0 = snmp session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = message to send
# arg4 = severity of the message (Normal, Warning, Minor, Major, Critical)
sub SendErrorEvent($$$$$);

# StartMaintenance is used to inform the manager that maintenance is starting on the node
# arg0 = snmp session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = user initiating maintenance
# arg4 = description text for the maintenance
# arg5 = number of minutes the maintenance will run
sub StartMaintenance($$$$$$);

# isActive returns true if the alarm for the given object/event was triggered or false otherwise.
# This is used to limit the triggered alarms to one per event.
# when the event is back to normal this is reset
sub isActive($);

# setActive sets the alarm status for the given object to the given state (true/false) to rememember if it is triggered or reset
sub setActive($$);

# GetConfigValues is used to read the two configuration files, and build global values with info
sub GetConfigValues();

# Function to parse the data got from the OS.
# The first parameter is the script to run to get the data depending on OS
sub ParseData($);

# Check the thresholds and send info to manager
#1st argument = snmp session
sub checkData($);

# Function to parse command line arguments
sub ParseArgs();

#helper function to trim spaces
sub trim($);

#returns the current time as string DD-MM-YYY HH-MM-SS
sub NowStr();

#Opens an SNMP session
#1st param = destination
#returns the SNMP session
sub SNMPOpen($);

#Closes the SNMP session
#1st param = the session to close
sub SNMPClose($);

########## MAIN PROGRAM BEGIN ##########

#include the SNMP utils
use Net::SNMP qw( :ALL );

#enable display flush
$| = 1;

$VER = "1.13";

#what is the OS we run on
$OS=$^O;
$PLATFORM="";
if ( $OS =~ /MSWin32/ ) { $PLATFORM="WIN"; }
if ( $OS =~ /linux/ ) { $PLATFORM="UX"; }
if ( $OS =~ /aix/ ) { $PLATFORM="UX"; }
if ( $OS =~ /hpux/ ) { $PLATFORM="UX"; }

#set this to 1 not to send traps - use it for dubug and tests
$DO_NOT_SEND = 0;

## Other initializations
%EVENT_STATUS=(); #keeps the status (triggered / reset) of each event

#Where the script is located (script's path)
use FindBin '$Bin';
$SCRIPTS_PATH = $Bin;

#what are the config files
$GLOBAL_CONF_FILE = ($SCRIPTS_PATH ne "" ? $SCRIPTS_PATH . "/" : "") . "Monitoring.conf";
$LOCAL_CONF_FILE = ($SCRIPTS_PATH ne "" ? $SCRIPTS_PATH . "/" : "") . "Local_Monitoring.conf";

#what is the script to run to get info
$SCRIPT_WIN = ($SCRIPTS_PATH ne "" ? $SCRIPTS_PATH . "/" : "") . "sysinfo.exe";
$SCRIPT_LINUX = ($SCRIPTS_PATH ne "" ? $SCRIPTS_PATH . "/" : "./") . "sysinfo.sh";
$SCRIPT_AIX = ($SCRIPTS_PATH ne "" ? $SCRIPTS_PATH . "/" : "./") . "sysinfo.aix.ksh";
$SCRIPT_HPUX = ($SCRIPTS_PATH ne "" ? $SCRIPTS_PATH . "/" : "./") . "sysinfo.hpux.ksh";

## Set the data gathering application
$SYSINFO="";
#if we run on windows
if ( $OS eq "MSWin32" ) { $SYSINFO=$SCRIPT_WIN; }
#if we run on linux
if ( $OS eq "linux") { $SYSINFO=$SCRIPT_LINUX; }
#if we run on aix
if ( $OS eq "aix") { $SYSINFO=$SCRIPT_AIX; }
#if we run on aix
if ( $OS eq "hpux") { $SYSINFO=$SCRIPT_HPUX; }

## Initialize the global vars and arrays
$DEBUG = 0;
$DAEMON = 0;
$PIDFILE = "";
$OUTPUT = "";

#read arguments from the command line
ParseArgs();

#what are the logfile, pidfile
if ($PIDFILE eq ".")
{
 $PIDFILE = ($SCRIPTS_PATH ne "" ? $SCRIPTS_PATH . "/" : "") . "ugmon.pid";
}
if ($OUTPUT eq ".")
{
 $OUTPUT = ($SCRIPTS_PATH ne "" ? $SCRIPTS_PATH . "/" : "") . "ugmon.log";
}


#if it is unix/linux
if ($OS ne "MSWin32")
{
  #daemonize if requested
  if ($DAEMON == 1)
  {
     use Proc::Daemon;
     Proc::Daemon::Init;
  }

 #catch the TERM signal
 $SIG{TERM} = sub { $continue = 0 };
}


#Redirect the output if requested
if ($OUTPUT ne "")
{
  open STDOUT, '>', $OUTPUT;
}

#Print some (debug) info
if ($DEBUG == 1)
{
  print "DEBUG: OS: $OS\n";
  print "DEBUG: Script's path: $SCRIPTS_PATH\n";
  print "DEBUG: Global conf file: $GLOBAL_CONF_FILE\n";
  print "DEBUG: Local conf file: $LOCAL_CONF_FILE\n";
  print "DEBUG: Info script: " . $SYSINFO . "\n";
  print "DEBUG: PID file: " . $PIDFILE . "\n";
  print "DEBUG: OUTPUT file: " . $OUTPUT . "\n";
  print "-----------------------------------------------------------\n";
}

#create a pidfile if requested
if ($PIDFILE ne "")
{
 open(FH, ">$PIDFILE");
 print FH "$$\n";
 close(FH);
}



#Read configuration from the config files and request info from OS to be used to send the initialization info to manager before the main loop starts
GetConfigValues();
ParseData($SYSINFO);

#send hello to the manager
if ($DO_NOT_SEND == 0)
{
 $session = SNMPOpen($CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" });
 SendHelloEvent( $session, $SYSINFO{"Hostname"}, $PLATFORM, $SYSINFO{"OS Version"},$VER);
 SNMPClose($session);
}

## MAIN LOOP

$continue = 1; #will run at least once if the pidfile is not created

while ( $continue )
{

  #Read configuration from the config files with each loop so that we get the last changes
  GetConfigValues();

  if ($DEBUG == 1)
  {
     print NowStr() . ": DEBUG: Configuration data:\n";
     for my $sect (keys %CONFIG)
     {
         print("[$sect]\n");
         for my $var ( keys %{$CONFIG{ $sect }} )
         {
             print "\t" . $var . " => " . $CONFIG{ $sect }{ $var } . "\n";
         }
     }
     print "---------------------------------------------------\n";
  }

  if ($DO_NOT_SEND == 0)
  {
     $session = SNMPOpen($CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" })
  }

  #TODO: here send the errors from the config file

  ##Get, parse data and send events
  if ($SYSINFO ne "")
  {
     ParseData($SYSINFO);
     checkData($session);
  }

  if ($DO_NOT_SEND == 0)
  {
   SNMPClose($session);
  }


  #sleep here
  if ($continue)
  {
    $how_much = 600; #10 min by default
    if (exists $CONFIG{ "GLOBAL" }{ "PollInterval" } )
    {
       $how_much = $CONFIG{ "GLOBAL" }{ "PollInterval" };
    }

    #stopping condition
    if ($PIDFILE eq "")
    {
       $continue = 0; #stop if there is no pidfile defined
    } else { #we have a pid file defined

       if ($DEBUG == 1) { print(NowStr() . ": DEBUG: Sleep for " . $how_much . " sec ...\n"); }
       for($i=1;$i <= $how_much/2; $i++)
       {
         if (! -e $PIDFILE)
         {
           $continue = 0;
         } else {
           sleep(2);
         }
         last if (! $continue); #stop if a pidfile is defined but it does not exist (or a term signal was sent)
       }
    }

  }




} #main loop

if ($DO_NOT_SEND == 0)
{
  #send goodby to the manager
  $session = SNMPOpen($CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" });
  SendGoodbyEvent( $session,$SYSINFO{"Hostname"}, $PLATFORM, $SYSINFO{"OS Version"},$VER);
  SNMPClose($session);
}


if ($DEBUG == 1) { print(NowStr() . ": DEBUG: Exit\n"); }

########## MAIN PROGRAM END ##########








# arg0 = SNMP session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = name of the volume to which the value belongs
# arg4 = total capacity in megabytes
# arg5 = free megabytes on the volume
sub SendDiskMetricEvent($$$$$$)
{
  if ($DO_NOT_SEND == 1) { return; }

	my $upTime = int(600);
	my $session = shift @_; #session
        if (!defined $session) { return; }
	my $localhost = shift @_; # localhost
	my $platform = shift @_; # platform
	my $volume = shift @_; #volume name
	my $total = shift @_; #total space MB
	my $free = shift @_; #free space MB
	my $trapOid = '1.3.6.1.4.1.15282.10.0.2';
	my $community = "public";
	my $genTrapvarOid = '1.3.6.1.4.1.15282.11.1.0';
	
	$platform = $platform eq "WIN" ? $platform : "UX";

        $result = $session->inform_request(
                -varbindlist => [
                '1.3.6.1.2.1.1.3.0',     TIMETICKS,         $upTime,
                '1.3.6.1.6.3.1.1.4.1.0', OBJECT_IDENTIFIER, $trapOid,
                $genTrapvarOid,     OCTET_STRING,      $localhost,
                $genTrapvarOid,     OCTET_STRING,      $platform,
                $genTrapvarOid,     OCTET_STRING,      $volume,
                $genTrapvarOid,     OCTET_STRING,      $total,
                $genTrapvarOid,     OCTET_STRING,      $free
                ]
                );

        if (!defined $result) {
        	
           	printf NowStr() . ": ERROR: %s.\n", $session->error();
        }
}

# arg0 = SNMP session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = name of the process
# arg4 = the actual state of the process (RUNNING, NOTRUNNING)
# arg5 = the desired state of the process (RUNNING, NOTRUNNING)
# arg6 = message group
# arg7 = severity
sub SendProcessFailureEvent($$$$$$$$)
{
    if ($DO_NOT_SEND == 1) { return; }

       	my $upTime = int(600);
       	my $session = shift @_; #session
        if (!defined $session) { return; }
		my $localhost = shift @_; # localhost
		my $platform = shift @_; # platform
		my $proc = shift @_; #process name
		my $state = shift @_; #current state
		my $normal_state = shift @_; #normal state
		my $msggroup = shift @_; #message group
		my $severity = shift @_; #severity
		my $trapOid = '1.3.6.1.4.1.15282.10.0.3';
		my $community = "public";
		my $genTrapvarOid = '1.3.6.1.4.1.15282.11.1.0';
		
		$platform = $platform eq "WIN" ? $platform : "UX";

        $result = $session->inform_request(
                -varbindlist => [
                '1.3.6.1.2.1.1.3.0',     TIMETICKS,         $upTime,
                '1.3.6.1.6.3.1.1.4.1.0', OBJECT_IDENTIFIER, $trapOid,
                $genTrapvarOid,     OCTET_STRING,      $localhost,
                $genTrapvarOid,     OCTET_STRING,      $platform,
                $genTrapvarOid,     OCTET_STRING,      $proc,
                $genTrapvarOid,     OCTET_STRING,      $state,
                $genTrapvarOid,     OCTET_STRING,      $normal_state,
				$genTrapvarOid,     OCTET_STRING,      $msggroup,
				$genTrapvarOid,     OCTET_STRING,      $severity
                ]
                );

        if (!defined $result) {
           printf NowStr() . ": ERROR: %s.\n", $session->error();
        }
}

# arg0 = the snmp session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = name of the service
# arg4 = actual state of the service (RUNNING, NOTRUNNING)
# arg5 = desired state of the service (RUNNING, NOTRUNNING)
# arg6 = display label of the service
# arg7 = message group
# arg8 = severity
sub SendServiceFailureEvent($$$$$$$$$)
{
    if ($DO_NOT_SEND == 1) { return; }

       my $upTime = int(600);
       my $session = shift @_; #session
       if (!defined $session) { return; }
		my $localhost = shift @_; # localhost
		my $platform = shift @_; # platform
		my $serv = shift @_; #service name
		my $state = shift @_; #current state
		my $normal_state = shift @_; #normal state
	   	my $title = shift @_; #service title
	   	my $msggroup = shift @_; #message group
	   	my $severity = shift @_; #severity
		my $trapOid = '1.3.6.1.4.1.15282.10.0.4';
		my $community = "public";
		my $genTrapvarOid = '1.3.6.1.4.1.15282.11.1.0';
		
		$platform = $platform eq "WIN" ? $platform : "UX";

        $result = $session->inform_request(
                -varbindlist => [
                '1.3.6.1.2.1.1.3.0',     TIMETICKS,         $upTime,
                '1.3.6.1.6.3.1.1.4.1.0', OBJECT_IDENTIFIER, $trapOid,
                $genTrapvarOid,     OCTET_STRING,      $localhost,
                $genTrapvarOid,     OCTET_STRING,      $platform,
                $genTrapvarOid,     OCTET_STRING,      $serv,
                $genTrapvarOid,     OCTET_STRING,      $state,
                $genTrapvarOid,     OCTET_STRING,      $normal_state,
                $genTrapvarOid,     OCTET_STRING,      $title,
				$genTrapvarOid,     OCTET_STRING,      $msggroup,
				$genTrapvarOid,     OCTET_STRING,      $severity
                ]
                );

        if (!defined $result) {
           printf NowStr() . ": ERROR: %s.\n", $session->error();
        }
}

# arg0 = snmp session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = cluster resource group name
# arg4 = cluster name
# arg5 = cluster group (up, down, partup)
sub SendClusterStateEvent($$$$$$)
{
    if ($DO_NOT_SEND == 1) { return; }

       my $upTime = int(600);
       my $session = shift @_; #session
        if (!defined $session) { return; }
	my $localhost = shift @_; # localhost
	my $platform = shift @_; # platform
	my $group = shift @_; #cluster resource group name
	my $name = shift @_; #cluster name
	my $state = shift @_; #group state
	my $trapOid = '1.3.6.1.4.1.15282.10.0.5';
	my $community = "public";
	my $genTrapvarOid = '1.3.6.1.4.1.15282.11.1.0';
	
	$platform = $platform eq "WIN" ? $platform : "UX";

        $result = $session->inform_request(
                -varbindlist => [
                '1.3.6.1.2.1.1.3.0',     TIMETICKS,         $upTime,
                '1.3.6.1.6.3.1.1.4.1.0', OBJECT_IDENTIFIER, $trapOid,
                $genTrapvarOid,     OCTET_STRING,      $localhost,
                $genTrapvarOid,     OCTET_STRING,      $platform,
                $genTrapvarOid,     OCTET_STRING,      $group,
                $genTrapvarOid,     OCTET_STRING,      $name,
                $genTrapvarOid,     OCTET_STRING,      $state
                ]
                );

        if (!defined $result) {
           printf NowStr() . ": ERROR: %s.\n", $session->error();
        }
}


# StartMaintenance is used to inform the manager that maintenance is starting on the node
# arg0 = snmp session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = user initiating maintenance
# arg4 = description text for the maintenance
# arg5 = number of minutes the maintenance will run
sub StartMaintenance($$$$$$)
{
    if ($DO_NOT_SEND == 1) { return; }

     my $upTime = int(600);
     my $session = shift @_; #session
        if (!defined $session) { return; }
	my $localhost = shift @_; # localhost
	my $platform = shift @_; # platform
	my $user = shift @_; #username
	my $descr = shift @_; #description
	my $duration = shift @_; #duration in min
	my $trapOid = '1.3.6.1.4.1.15282.10.0.6';
	my $community = "public";
	my $genTrapvarOid = '1.3.6.1.4.1.15282.11.1.0';
	
	$platform = $platform eq "WIN" ? $platform : "UX";

        $result = $session->inform_request(
                -varbindlist => [
                '1.3.6.1.2.1.1.3.0',     TIMETICKS,         $upTime,
                '1.3.6.1.6.3.1.1.4.1.0', OBJECT_IDENTIFIER, $trapOid,
                $genTrapvarOid,     OCTET_STRING,      $localhost,
                $genTrapvarOid,     OCTET_STRING,      $platform,
                $genTrapvarOid,     OCTET_STRING,      $user,
                $genTrapvarOid,     OCTET_STRING,      $descr,
                $genTrapvarOid,     OCTET_STRING,      $duration
                ]
                );

        if (!defined $result) {
           printf NowStr() . ": ERROR: %s.\n", $session->error();
        }

}


# arg0 = snmp session
# arg1 = local hostname
# arg2 = platform <WIN|UX>
# arg3 = message to send
# arg4 = severity of the message (Normal, Warning, Minor, Major, Critical)
sub SendErrorEvent($$$$$)
{
    if ($DO_NOT_SEND == 1) { return; }

       my $upTime = int(600);
       my $session = shift @_; #session
        if (!defined $session) { return; }
	my $localhost = shift @_; # localhost
	my $platform = shift @_; # platform
	my $msg = shift @_; #message
	my $sev = shift @_; #severity
	my $trapOid = '1.3.6.1.4.1.15282.10.0.7';
	my $community = "public";
	my $genTrapvarOid = '1.3.6.1.4.1.15282.11.1.0';
	
	$platform = $platform eq "WIN" ? $platform : "UX";

        $result = $session->inform_request(
                -varbindlist => [
                '1.3.6.1.2.1.1.3.0',     TIMETICKS,         $upTime,
                '1.3.6.1.6.3.1.1.4.1.0', OBJECT_IDENTIFIER, $trapOid,
                $genTrapvarOid,     OCTET_STRING,      $localhost,
                $genTrapvarOid,     OCTET_STRING,      $platform,
                $genTrapvarOid,     OCTET_STRING,      $msg,
                $genTrapvarOid,     OCTET_STRING,      $sev
                ]
                );

        if (!defined $result) {
           printf NowStr() . ": ERROR: %s.\n", $session->error();
        }
}


# arg0 = snmp session
# arg1 = FQN of the host on which the agent runs (physical node name)
# arg2 = platform <WIN|UX>
# arg3 = OS version
# arg4 = UGMon version
sub SendHelloEvent($$$$$)
{
    if ($DO_NOT_SEND == 1) { return; }

       my $upTime = int(600);
       my $session = shift @_; #session
        if (!defined $session) { return; }
	my $localhost = shift @_; # localhost
	my $platform = shift @_; # platform
	my $flavor = shift @_; #OS version 
	my $ver = shift @_; #UGMon version
	my $trapOid = '1.3.6.1.4.1.15282.10.0.8';
	my $community = "public";
	my $genTrapvarOid = '1.3.6.1.4.1.15282.11.1.0';

        $result = $session->inform_request(
                -varbindlist => [
                '1.3.6.1.2.1.1.3.0',     TIMETICKS,         $upTime,
                '1.3.6.1.6.3.1.1.4.1.0', OBJECT_IDENTIFIER, $trapOid,
                $genTrapvarOid,     OCTET_STRING,      $localhost,
                $genTrapvarOid,     OCTET_STRING,      $platform,
                $genTrapvarOid,     OCTET_STRING,      $flavor,
                $genTrapvarOid,     OCTET_STRING,      $ver
                
                ]
                );

        if (!defined $result) {
           printf NowStr() . ": ERROR: %s.\n", $session->error();
        }
}


# Sends Goodby event to manager from given hostname
# arg0 = snmp session
# arg1 = FQN of the host on which the agent runs (physical node name)
# arg2 = platform <WIN|UX>
# arg3 = OS version
# arg4 = UGMon version
sub SendGoodbyEvent($$$$$)
{
    if ($DO_NOT_SEND == 1) { return; }

       my $upTime = int(600);
        my $session = shift @_; #session
        if (!defined $session) { return; }
	my $localhost = shift @_; # localhost
	my $platform = shift @_; # platform
	my $flavor = shift @_; #OS version 
	my $ver = shift @_; #UGMon version
	my $trapOid = '1.3.6.1.4.1.15282.10.0.9';
	my $community = "public";
	my $genTrapvarOid = '1.3.6.1.4.1.15282.11.1.0';
	
	$platform = $platform eq "WIN" ? $platform : "UX";

        $result = $session->inform_request(
                -varbindlist => [
                '1.3.6.1.2.1.1.3.0',     TIMETICKS,         $upTime,
                '1.3.6.1.6.3.1.1.4.1.0', OBJECT_IDENTIFIER, $trapOid,
                $genTrapvarOid,     OCTET_STRING,      $localhost,
                $genTrapvarOid,     OCTET_STRING,      $platform,
                $genTrapvarOid,     OCTET_STRING,      $flavor,
                $genTrapvarOid,     OCTET_STRING,      $ver
                ]
                );

        if (!defined $result) {
           printf NowStr() . ": ERROR: %s.\n", $session->error();
        }
}


#1st param = destination
#returns the SNMP session
sub SNMPOpen($)
{
 my ($session, $error) = Net::SNMP->session(
             -hostname  => shift @_,
             -community => 'public',
             -port      => 162,      # Need to use port 162
             -version   => 'snmpv2c',
             -timeout   => 2,
             -retries   => 3,
   );

   if (!defined $session) {
      printf NowStr() . ": ERROR: %s.\n", $error;
   }

   return $session;
}

#1st parameter = the SNMP sesssion to close
sub SNMPClose($)
{
  if (defined $session) { $session->close(); }
}


sub isActive($)
{
    return $EVENT_STATUS{ $_[0] } if exists $EVENT_STATUS{ $_[0] };

    return 0;
}

sub setActive($$)
{
   $EVENT_STATUS{ $_[0] } = $_[1];
}


# Function to parse the data got from the OS.
# The first parameter is the script to run to get the data depending on OS
sub ParseData($)
{
  @SERVICES = ();
  @PROCESSES = ();
  @VOLUMES = ();
  %SYSINFO = ();

  #read info from OS
  if ($DEBUG == 1) { print(NowStr() . ": DEBUG: Read data from $_[0].\n"); }
  $filename = $_[0];
  if (! -e $filename) { print NowStr() . ": ERROR: The data file $filename does not exist.\n"; return; }
  open(FILE,'-|',$filename) or die NowStr() . ": ERROR: Could not open the pipe.\n";
  my $section = "unknown";
  while (my $line = <FILE>)
  {
    chomp($line);
    if ( $line !~ /^#/ && $line =~ /.+/)  #skip if comment or empty
    {
       if (grep($line =~ /^$_/,("END SYSINFO","END SERVICES","END PROCESSES","END VOLUMES"))) { $section = "unknown"; }

       if ($section =~ /^BEGIN SERVICES/ ) { push(@SERVICES,$line); }
       if ($section =~ /^BEGIN PROCESSES/) { push(@PROCESSES,$line); }
       if ($section =~ /^BEGIN VOLUMES/) { push(@VOLUMES,$line); }
       if ($section =~ /^BEGIN SYSINFO/)
       {
             ( $key, $val ) = split(":",$line,2);
             $key = trim($key);
             $val = trim($val);
             $SYSINFO{$key} = $val;
             if ($DEBUG == 1) { print(NowStr() . ": DEBUG: SYSINFO: $key : $SYSINFO{$key}\n"); }
       }

       if (grep($line =~ /^$_/,("BEGIN SYSINFO","BEGIN SERVICES","BEGIN PROCESSES","BEGIN VOLUMES"))) { $section = $line; }

    }
  }
  close(FILE);
  #set some dummy defaults in case of undefined to avoid the crash
  if (! defined $SYSINFO{"Hostname"} ) { $SYSINFO{"Hostname"} = "localhost"; }
  if (! defined $SYSINFO{"OS Version"} ) { $SYSINFO{"OS Version"} = "N/A"; }
  
  ##### TESTING ONLY - REMOVE THIS ############
  #$SYSINFO{"Hostname"} = "inf-t-022.de-test.dk";
}


# Check the thresholds and send info to manager
#1st argument = snmp session
sub checkData($)
{

  $session = shift @_; #snmp session

  #check SERVICES
  if ($PLATFORM eq "WIN")
  {
    foreach $cfg_serv (keys %{$CONFIG{ "SERVICES" } } )
    {
      ($normal_state, $alarm_on_missing,$msg_group,$severity) = split(",", $CONFIG{ "SERVICES" }{ $cfg_serv});
      if ($normal_state eq "IGNORED")
      {
        if ($DEBUG == 1) { print(NowStr() . ": DEBUG: Ignore the service $cfg_serv ...\n"); }
        next;
      }
      if ($DEBUG == 1) { print(NowStr() . ": DEBUG: Checking the service $cfg_serv ...\n"); }
      $found = 0;
      foreach $sys_serv ( @SERVICES)
      {
        ($serv,$state,$label) = split("\t",$sys_serv);
        if ($serv eq $cfg_serv) { $found = 1; last; }
      }
      if ($found == 1) #service found (installed)
      {
        if ($DEBUG == 1) { print(NowStr() . ": DEBUG: The service $cfg_serv is installed ($serv,$state,$label).\n"); }
        $state = $state == 4 ? "RUNNING" : "NOTRUNNING";
        if (uc($normal_state) ne $state) #service found and normal_state != state
        {
          if (isActive($cfg_serv) == 0) #do not send it again if sent already
          {
             if ($DEBUG == 1)
             {
               print(NowStr() . ": SEND ALARM: Dest: " . $CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" } .
                     " Src: " . $SYSINFO{"Hostname"} .
                     ". The state of the service $cfg_serv ($state) is different than the normal state ($normal_state)\n");
             }
             SendServiceFailureEvent(       $session,
                                            $SYSINFO{"Hostname"},
                                            $PLATFORM,
                                            $cfg_serv,
                                            $state,
                                            $normal_state,
                                            $label,
                                            $msg_group,
                                            $severity);
             setActive($cfg_serv,1);
          } else {
            if ($DEBUG == 1) { print("DEBUG: Alarm already sent for $cfg_serv\n"); }
          }
        } else { #service found and normal_state = state
          if (isActive($cfg_serv) == 1) #set to normal only if already triggered 
          {
             if ($DEBUG == 1)
             {
               print(NowStr() . ": SEND RESET: Dest: " . $CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" } .
                     " Src: " . $SYSINFO{"Hostname"} .
                     ". The state of the service $cfg_serv ($state) is back to normal state ($normal_state)\n");
             }
             setActive($cfg_serv,0);
             SendServiceFailureEvent(       $session,
                                            $SYSINFO{"Hostname"},
                                            $PLATFORM,
                                            $cfg_serv,
                                            $state,
                                            $normal_state,
                                            $label,
                                            $msg_group,
                                            "Normal");
          }
        }
      } else { #service not found (not installed)
        if ($DEBUG == 1) { print(NowStr() . ": DEBUG: The service $cfg_serv is NOT installed. \n"); }
        if (lc($alarm_on_missing) eq "true")
        {
          if (isActive($cfg_serv) == 0) #do not send it again if sent already
          {
             if ($DEBUG == 1) { print(NowStr() . ": SEND ALARM: The service $cfg_serv is NOT running.\n"); }

             SendServiceFailureEvent(       $session,
                                            $SYSINFO{"Hostname"},
                                            $PLATFORM,
                                            $cfg_serv,
                                            "MISSING",
                                            $normal_state,
                                            $cfg_serv,
                                            $msg_group,
                                            $severity);
             setActive($cfg_serv,1);
          }
        }
      }
    }
  }

  #check PROCESSES
  foreach $cfg_proc (keys %{$CONFIG{ "PROCESSES" } } )
  {
    ($normal_state,$msg_group,$severity) = split(",",$CONFIG{ "PROCESSES" }{ $cfg_proc});
    if ($normal_state eq "IGNORED")
    {
      if ($DEBUG == 1) { print(NowStr() . ": DEBUG: Ignore the process $cfg_proc ...\n"); }
      next;
    }
    if ($DEBUG == 1) { print(NowStr() . ": DEBUG: Checking the process $cfg_proc ...\n"); }
    $found = 0;
    foreach $sys_proc ( @PROCESSES)
    {
      if ($sys_proc eq $cfg_proc) { $found = 1; last; }
    }
    if ($found == 1) #process found
    {
      if ($DEBUG == 1) { print(NowStr() . ": DEBUG: The process $cfg_proc is running.\n"); }
      if (uc($normal_state) ne "RUNNING" )  #process found and normal_state = NOTRUNNING
      {
        if (isActive($cfg_proc) == 0) #do not send it again if sent already
        {
           if ($DEBUG == 1) 
           { 
             print(NowStr() . ": SEND ALARM: Dest: " . $CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" } . 
                   " Src: " . $SYSINFO{"Hostname"} .
                   ". The process $cfg_proc is running ($state) although its normal state is $normal_state\n");
           }
           SendProcessFailureEvent(         $session,
                                            $SYSINFO{"Hostname"},
                                            $PLATFORM,
                                            $cfg_proc,
                                            "RUNNING",
                                            $normal_state,
                                            $msg_group,
                                            $severity
                                            );
           setActive($cfg_proc,1);
        } else {
            if ($DEBUG == 1) { print(NowStr() . ": DEBUG: Alarm already sent for $cfg_proc\n"); }
        }
      } else { #process found and normal_state = RUNNING
        if (isActive($cfg_proc) == 1) #set to normal only if already triggered
        {
           if ($DEBUG == 1)
           {
              print(NowStr() . ": SEND RESET: Dest: " . $CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" } .
                    " Src: " . $SYSINFO{"Hostname"} .
                    ". The process $cfg_proc is back to its normal state ($normal_state)\n");
           }
           setActive($cfg_proc,0);
           SendProcessFailureEvent(         $session,
                                            $SYSINFO{"Hostname"},
                                            $PLATFORM,
                                            $cfg_proc,
                                            "RUNNING",
                                            $normal_state,
                                            $msg_group,
                                            "Normal"
                                            );
        }
      }
    } else { #process not found
      if ($DEBUG == 1) { print(NowStr() . ": DEBUG: The process $cfg_proc is NOT running.\n"); }
      if (uc($normal_state) ne "NOTRUNNING" ) #process not found and normal_state = RUNNING
      {
        if (isActive($cfg_proc) == 0) #do not send it again if sent already
        {
           if ($DEBUG == 1)
           {
              print(NowStr() . ": SEND ALARM: Dest: " . $CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" } .
                    " Src: " . $SYSINFO{"Hostname"} .
                    ". The process $cfg_proc is NOT running although its normal state is $normal_state\n");
           }
           SendProcessFailureEvent( $session,
                                    $SYSINFO{"Hostname"},
                                    $PLATFORM,
                                    $cfg_proc,
                                    "NOTRUNNING",
                                    $normal_state,
                                    $msg_group,
                                    $severity
                                    );
           setActive($cfg_proc,1);
        } else {
            if ($DEBUG == 1) { print(NowStr() . ": DEBUG: Alarm already sent for $cfg_proc\n"); }
        }
      } else { #process not found and normal_state = NOTRUNNING
        if (isActive($cfg_proc) == 1) #set to normal only if already triggered
        {
           if ($DEBUG == 1)
           {
              print(NowStr() . ": SEND RESET: Dest: " . $CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" } .
                    " Src: " . $SYSINFO{"Hostname"} .
                    ". The process $cfg_proc is back to its normal state ($normal_state)\n");
           }
           setActive($cfg_proc,0);
           SendProcessFailureEvent(         $session,
                                            $SYSINFO{"Hostname"},
                                            $PLATFORM,
                                            $cfg_proc,
                                            "NOTRUNNING",
                                            $normal_state,
                                            $msg_group,
                                            "Normal"
                                            );
        }
      }
    }
  }

  #check VOLUMES
  foreach $sys_vol (@VOLUMES)
  {
     ($vol_label, $vol_id, $total, $free) = split("\t",$sys_vol);
     $found = 0;
     foreach $cfg_vol (keys %{$CONFIG{ "VOLUMES" }})
     {
         if ($vol_label =~ /$cfg_vol/ )  #found it
         {
           if ($CONFIG{ "VOLUMES" }{$cfg_vol} eq "IGNORED")
           {
             if ($DEBUG == 1)
             {
               print(NowStr() . ": DEBUG: Ignore $vol_label\n");
             }
           } else {
             $found = 1;
           }
           last;
         }
     }
     next if ($found == 0);
     if (defined $total && defined $free)
     {
       if ($DEBUG == 1)
       {
          print(NowStr() . ": SEND INFO: Dest: " . $CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" } .
                    " Src: " . $SYSINFO{"Hostname"} .
                    ". The volume $vol_label ($vol_id): $free free from $total.\n");
       }
       SendDiskMetricEvent( $session,
                          $SYSINFO{"Hostname"},
                          $PLATFORM,
                          $vol_label eq "" ? $vol_id : $vol_label,
                          $total,
                          $free);
     } else {
       if ($DEBUG == 1) { print(NowStr() . ": DEBUG: Skip $vol_label ($vol_id) since there is no total/free info.\n"); }
     }
  }


}


sub GetConfigValues()
{
  %CONFIG = ();

  #Read first the global config
  if ($DEBUG == 1) { print(NowStr() . ": DEBUG: read from main config file.\n"); }
  $cfgfile = $GLOBAL_CONF_FILE;
  if (! -e $cfgfile) { print NowStr() . ": ERROR: The main configuration file $cfgfile does not exist.\n"; return; }
  open(FILE,$cfgfile) or die NowStr() . ": ERROR: Could not open the main configuration file: $!\n";
  my $section = "unknown";
  while (my $line = <FILE>)
  {
    chomp($line);
    if ( $line !~ /^#/ && $line =~ /.+/ )  #skip if comment or empty
    {
       if ( $line =~ /^\[/ )
       {
         if ($line =~ /^\[GLOBAL\]/) { $section = "GLOBAL"; }
         if ($line =~ /^\[SERVICES\]/) { $section = "SERVICES"; }
         if ($line =~ /^\[PROCESSES\]/) { $section = "PROCESSES"; }
         if ($line =~ /^\[VOLUMES\]/) { $section = "VOLUMES"; }

       } else {
         @vals = split(/\s+/, $line);
         if ($section eq "GLOBAL") { if ($#vals >= 1) { $CONFIG{ $section }{ $vals[0] } = join(" ", @vals[1 .. $#vals]); } }
         if ($section eq "SERVICES") { if ($#vals >= 4) { $CONFIG{ $section }{ join(" ", @vals[0 .. $#vals-4]) } = join(",", @vals[$#vals-3 .. $#vals]); } }
         if ($section eq "PROCESSES") { if ($#vals >= 3) { $CONFIG{ $section }{ join(" ", @vals[0 .. $#vals-3]) } = join(",", @vals[$#vals-2 .. $#vals]); } }
         if ($section eq "VOLUMES") { if ($#vals >= 0) { $CONFIG{ $section }{ $vals[0] } =  $#vals == 1 ? $vals[1] : $vals[0]; } }
       }
    }
  }
  close(FILE);

  #Read the local config
  if ($DEBUG == 1) { print(NowStr() . ": DEBUG: read from local config file.\n"); }
  $cfgfile = $LOCAL_CONF_FILE;
  if (! -e $cfgfile && $DEBUG == 1) { print NowStr() . ": DEBUG: The local configuration file $cfgfile does not exist.\n"; return; }
  open(FILE, $cfgfile) or die NowStr() . ": ERROR: Could not open the local configuration file: $!\n";
  $section = "unknown";
  while (my $line = <FILE>)
  {
    chomp($line);
    if ( $line !~ /^#/ && $line =~ /.+/ )  #skip if comment or empty
    {
       if ( $line =~ /^\[/ )
       {

         if ($line =~ /^\[GLOBAL\]/) { $section = "GLOBAL"; }
         if ($line =~ /^\[SERVICES\]/) { $section = "SERVICES"; }
         if ($line =~ /^\[PROCESSES\]/) { $section = "PROCESSES"; }
         if ($line =~ /^\[VOLUMES\]/) { $section = "VOLUMES"; }
       } else {
         @vals = split(/\s+/, $line);
         if ($section eq "GLOBAL") { if ($#vals >= 1) { $CONFIG{ $section }{ $vals[0] } = join(" ", @vals[1 .. $#vals]); } }
         if ($section eq "SERVICES") { if ($#vals >= 4) { $CONFIG{ $section }{ join(" ", @vals[0 .. $#vals-4]) } = join(",", @vals[$#vals-3 .. $#vals]); } }
         if ($section eq "PROCESSES") { if ($#vals >= 3) { $CONFIG{ $section }{ join(" ", @vals[0 .. $#vals-3]) } = join(",", @vals[$#vals-2 .. $#vals]); } }
         if ($section eq "VOLUMES") { if ($#vals >= 0) { $CONFIG{ $section }{ $vals[0] } =  $#vals == 1 ? $vals[1] : $vals[0]; } }
       }
    }
  }
  close(FILE);

  #set some dummy defaults if values are missing to avoid some crashes :-)
  if (! defined $CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" } ) {$CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" } = "127.0.0.1"; }
}


sub ParseArgs()
{

  if($#ARGV >= 0 && $ARGV[0] eq "-startMaint" )
  {
       if ($#ARGV < 3)
       {
          print("ERROR: Not enough parameters (use -? for help).");
          exit(0);
       }
       GetConfigValues();
       ParseData($SYSINFO);
       print("Sending maintenance start event to " . $CONFIG{ "GLOBAL" }{ "SnmpTrapDestination"} .
             " from " . $ARGV[1] . "@" . $SYSINFO{"Hostname"} . " for " . $ARGV[3] . " min, with text: " . $ARGV[2]);
       my $session = SNMPOpen($CONFIG{ "GLOBAL" }{ "SnmpTrapDestination" });
       StartMaintenance($session,
                        $SYSINFO{"Hostname"},
                        $PLATFORM,
                        $ARGV[1],
                        $ARGV[2],
                        $ARGV[3]);
       SNMPClose($session);
       exit(0);
  } else {
    foreach($i = 0; $i <= $#ARGV; $i++)
    {
       if($ARGV[$i] eq "-debug") { $DEBUG = 1; }
       if($ARGV[$i] eq "-daemon") { $DAEMON = 1; }
       if($ARGV[$i] eq "-pid" && $i + 1 <= $#ARGV) { $PIDFILE = $ARGV[$i+1]; }
       if($ARGV[$i] eq "-out" && $i + 1 <= $#ARGV) { $OUTPUT = $ARGV[$i+1]; }
       if($ARGV[$i] eq "-lout" ) { $OUTPUT = "."; }
       if($ARGV[$i] eq "-lpid" ) { $PIDFILE = "."; }
       if($ARGV[$i] eq "-?" || $ARGV[$i] eq "-h") {

         print "UGMon " . $VER . " - monitoring agent for windows and linux\n";
         print "2010 (c) Rubiksolutions\n\n";
         print "Usage 1: ugmon.pl [-debug] [-out filename | -lout] [-pid filename | -lpid] [-daemon] \n\n";
         print "\t-debug : sets debug mode and verbous mode\n\n";
         print "\t-out filename : redirects the output  (used if the default redirection '>' is not possible\n\n";
         print "\t-pid filename : sets the pid file (used to stop the process in win and linux when running as service/daemon)\n\n";
         print "\t-lout : creates a local (in the script's folder) file to redirect output. do not use together with -out\n\n";
         print "\t-lpid : creates a local (in the script's folder) pid file. do not use together with -pid\n\n";
         print "\t-daemon : daemonize (fork and stay running)\n\n";
         print "\t-h | -? : this help\n\n\n\n";
         print "Usage 2: ugmon.pl <-startMaint> <user> <description> <durationMins>\n\n";
         print "\t-startMaint : starts a maintenance front end\n\n";
         print "\tuser : the username\n\n";
         print "\tdescription : description text enclosed by \"\"\n\n";
         print "\tdurationMins : duration in minutes\n\n";
         exit(0);
       }
    }
  }
}

sub trim($)
{
  $string = $_[0];
  $string =~ s/^\s+//; #remove leading spaces
  $string =~ s/\s+$//; #remove trailing spaces
  return $string;
}

sub NowStr()
{
	my ($sec,$min,$hour,$day,$month,$yr19,@rest) =   localtime(time);
	return $day . "-" . $month . "-" . ($yr19 + 1900) . " " . $hour . ":" . $min . ":" . $sec; 
}