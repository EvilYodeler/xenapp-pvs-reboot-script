###############################################################################
# Reboot Script for Citrix Provisioned XenApp Servers
# Created 5-5-2011 by Ben Piper
# Modified 5-7-2013
#
#            This script must be executed under an account
#                 with full Administrative privileges
#
############################################################################### 
# Comments
# 	This script utilizes three primary output methods:
#	1. Email
#	2. Logging to file
#	3. Logging to Windows Application Log
#	
#	1 and 2 are configurable and can be turned off.  3 is not configurable
#	and cannot be turned off via the script settings.
###############################################################################
# Initialization and sanity checks
###############################################################################

# Specify the full path to the script containing the configuration variables (see README.md for help)
$configFile = "./reboot-config.ps1"

# Check for the configuration file

If ((Test-Path -path $configFile) -eq $True) {
	. $configFile
	}
else {
	Write-Host Configuration file $configFile not found. Exiting...
	break
	}

# Abort reboot if the personality string for rebootBypass is set to 0
$rebootBypass = get-content C:\Personality.ini | Select-String -Pattern "$personalityStringRebootBypass" | foreach-object {$_ -replace $personalitystringrebootbypass, ""}
if ($rebootBypass -ne 0) { exit }

Add-PSSnapin "Citrix.XenApp.Commands"

$Global:EventLog = New-Object -type System.Diagnostics.Eventlog -argumentlist Application # Creates a global object for logging to the Application event log
$Global:EventLog.Source = "$eventLogSource"
$processes=0
$powershells = @(get-process | Where {$_.ProcessName -eq "powershell"}) # Query all running processes to see if Powershell is running
foreach ($p in $powershells) {$processes+=1} 							# Validate that there is already a powershell instance running
if ($processes -gt 1) {$EventLog.WriteEntry("PowerShell is already running.  Terminating this instance.","Information","011");exit}

# Create event entry to note the start time of the script
$EventLog.WriteEntry("Starting scheduled reboot task.","Information","111")
if ($annoyUser -lt 1) {$annoyUser = 3}

# Randomize reboot delay
$rebootDelay = get-random -min $minRebootDelayMins -max $maxRebootDelayMins

# If aggression timer is set and exceeds the rebootDelay, pare it down
while ($aggression -gt $rebootDelay*60) {$aggression = $aggression/$annoyUser}

# If aggression timer is set to auto, make it reasonable
while ($aggression -lt 0) {$aggression = (($maxRebootDelayMins+$notifyDelay)/$notifyDelay)*60}

# If reboot delay is less than notification delay, increase reboot delay to twice the notification delay
if ($rebootDelay -lt $notifyDelay) {$rebootDelay = $notifyDelay * 2}
$Global:NoUsers = $False 					# Create a global variable for assessing active sessions
[string]$Global:ServerLoadEvaluator 		# Create a global load evaluator placeholder to be used for re-assigning the server's LE
$rebootEmail = get-content C:\Personality.ini | Select-String -Pattern "$personalityStringEmail" | foreach-object {$_ -replace $personalitystringemail, ""}	# Retrieve value from personality string
$rebootLogging = get-content C:\Personality.ini | Select-String -Pattern "$personalityStringLog" | foreach-object {$_ -replace $personalitystringlog, ""}	# Retrieve value from personality string
$waitOverride = get-content C:\Personality.ini | Select-String -Pattern "$personalityStringWaitOverride" | foreach-object {$_ -replace $personalitystringWaitOverride, ""}	# Retrieve value from personality string
if ($rebootEmail -ne 1 -and $rebootEmail -ne 0) { $rebootEmail = $defaultRebootEmail }	# Check that $rebootEmail value is valid, else set to $defaultRebootEmail
if ($rebootLogging -ne 1 -and $rebootLogging -ne 0) { $rebootLogging = $defaultRebootLogging } # Check that rebootLogging value is valid, else set to $defaultRebootLogging
if ($waitOverride -ne 1 -and $waitOverride -ne 0) { $waitOverride = 0 } # Check that waitOverride value is valid, else set to 0
###############################################################################

$NoLogonLEExists="False"
$NoLogonQuery = @(get-xaloadevaluator | Where {$_.LoadEvaluatorName -eq $Global:NoLogonLoadEvaluator}) # Query to see if NoLogonLoadEvaluator exists
foreach ($nl in $NoLogonQuery) {$NoLogonLEExists="True"} # Validate that the NoLogonLoadEvaluator exists or not
if ($NoLogonLEExists -eq "False") {$EventLog.WriteEntry($Global:NoLogonLoadEvaluator + " Load Evaluator does not exist. Creating " + $Global:NoLogonLoadEvaluator + " Load Evaluator.","Information","141");new-xaloadevaluator $Global:NoLogonLoadEvaluator -description "Temporary Load Evaluator used to report a full load for Citrix Rolling Reboot task" -cpuutilization 0,1
} else {} # Load Evaluator does not exists, creating NoLogonLoadEvaluator

###############################################################################

function AssignLE {
set-xaServerLoadEvaluator -LoadEvaluatorName $args[0] -ServerName $args[1] # Assign Load Evaluator as passed through as first variable to server as passed through as second variable
}

###############################################################################

function GetLE {
$Global:ServerLoadEvaluator = (Get-xaLoadEvaluator -ServerName $args[0]).LoadEvaluatorName # Get Load Evaluator for server as passed as first variable
}

###############################################################################

function CheckConnections {
 $i=0 				# Create a zero valued integer to count number of concurrent sessions
 $timespanleft = "$args" 	# Create a variable named server from the first passed variable
  $sessions = @(get-xasession | Where {$_.ServerName -eq $env:computername} | Where {$_.State -ne "Listening"} | Where {$_.State -ne "Disconnected"} | Where {$_.SessionName -ne "Console"}) # Create a query against server passed through as first variable where protocol is Ica. Disregard disconnected or listening sessions
  foreach ($session in $sessions) {$i+=1} # Count number of sessions
  if ($i -eq 0) {$Global:NoUsers = $True; $EventLog.WriteEntry("Server " + $env:computername + " has no active sessions.","Information","311")}
	else {
		if ($rebootEmail -eq 1) {
			Send-MailMessage -SmtpServer $smtpServer -To $smtpAlerts -From $env:computername@$smtpDomain -Subject $loggedinS -Body $loggedinB$timespanleft" minutes"
		}
		if ($rebootLogging -eq 1) {
			$now = get-date
			$logdata = $now.toString()+" $loggedinB$timespanleft minutes"
			$logdata | Add-Content -path "$logfilepath\$env:computername.txt"
		}
	}
}

###############################################################################

function CountDown($waitMinutes) {
    $startTime = get-date
    $endTime   = $startTime.addMinutes($waitMinutes)
    $timeSpan = new-timespan $startTime $endTime
	$startNotifyTime = $startTime.addminutes($notifyDelay)
	$notifyTimeSpan = new-timespan $startTime $startNotifyTime
    write-host "`nForced reboot in $waitMinutes minutes..." -backgroundcolor black -foregroundcolor yellow
    while ($timeSpan -gt 0) {
        $timeSpan = new-timespan $(get-date) $endTime
		$notifyTimeSpan = new-timespan $(get-date) $startNotifyTime
        write-host "`r".padright(40," ") -nonewline
        write-host $([string]::Format("`rTime Remaining: {0:d2}:{1:d2}:{2:d2}", `
            $timeSpan.hours, `
            $timeSpan.minutes, `
            $timeSpan.seconds)) `
            -nonewline -backgroundcolor black -foregroundcolor yellow
        #Do {CheckConnections $env:computername} while ($NoUsers -eq $False) # Check for active sessions using the CheckConnections function above
		$totalMinutes = "{0:N0}" -f $timeSpan.totalminutes
		CheckConnections $totalMinutes
		if ($NoUsers -eq $True) { 	# Continue processing if there are no active sessions
			if ($rebootEmail -eq 1) {
				Send-MailMessage -SmtpServer $smtpServer -To $smtpAlerts -From $env:computername@$smtpDomain -Subject $rebootS -Body $rebootB
			}
			if ($rebootLogging -eq 1) {
				$now = get-date
				$logdata = $now.toString()+" $rebootB"
				$logdata | Add-Content -path "$logfilepath\$env:computername.txt"
			}
			$randomRebootDelay = get-random -minimum 0 -maximum $maxRandomRebootDelaySecs
			sleep $randomRebootDelay
			StartReboot $server 	# Initialize the StartReboot function 
		}
		$allSessions = Get-XASession -servername $env:computername | Where {$_.State -ne "Listening"} | Where {$_.State -ne "Disconnected"} | Where {$_.SessionName -ne "Console"}
		if ($notifyTimeSpan -lt 0) {	# If notifyDelay time has elapsed
			if ($annoyUser -gt 0) {		# send a message to the logged-in users
				Send-XASessionMessage -InputObject $allSessions -messagetitle $messageTitle -messageBody "The system will be restarting in $totalMinutes Minutes"
				$annoyUser--
			}
		}
		sleep $aggression
        }
    #Time's up! REBOOT!
	$EventLog.WriteEntry("Server " + $server + " kill timer expired.  Forced reboot initiated.","Information","311")
	if ($rebootEmail -eq 1) {
		Send-MailMessage -SmtpServer $smtpServer -To $smtpAlerts -From $env:computername@$smtpDomain -Subject $forcedRebootS -Body $forcedRebootB
	}
	if ($rebootLogging -eq 1) {
		$now = get-date
		$logdata = $now.toString()+" $i users logged in`n"
		$logdata += $now.toString()+" $forcedRebootB"
		$logdata | Add-Content -path "$logfilepath\$env:computername.txt"
	}
	
	StartReboot $server # Initialize the StartReboot function
	write-host "Time expired"
    }
	
###############################################################################

function StartReboot {
 $EventLog.WriteEntry("Initiating forced reboot.","Information","911")
 sleep $shutdownTimer
 AssignLE $ServerLoadEvaluator $env:computername
 restart-computer -force
}

###############################################################################
# Main Program
###############################################################################
try {
	if ($waitoverride -eq 1) {
		GetLE $env:computername
		$EventLog.WriteEntry("Wait override active","Information","911")
		if ($rebootLogging -eq 1) {
			$now = get-date
			$logdata = $now.toString()+" Wait override active. Rebooting in $shutdownTimer seconds"
			$logdata | Add-Content -path "$logfilepath\$env:computername.txt"
		}
		StartReboot $server
	}
	else {
		write-host "Aggression  : $aggression seconds"
		write-host "Reboot delay: $rebootDelay minutes"
		write-host "Warnings    : $annoyUser"
		$Global:NoUsers = $False				# Reset the nousers variable to False
		GetLE $env:computername				# Assign ServerLoadEvaluator variable the current load evaluator value
		AssignLE $NoLogonLoadEvaluator $env:computername # Assign the nologon load evaluator before processing each server
		$EventLog.WriteEntry("Assigning " + $NoLogonLoadEvaluator + " Load Evaluator to " + $env:computername + ".","Information","411")
		CountDown $rebootDelay		# Start kill timer
	}
  }
catch {
	$EventLog.WriteEntry("Unhandled error has occurred in main program: " + $error[0],"Information")
	write-host "Unhandled error has occurred in main program: "$error[0]
	}
