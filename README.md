Summary:
This is a Windows PowerShell script designed to achieve the following:
* Reboot Citrix XenApp servers provisioned using Citrix Provisioning Services
* Stagger reboots to avoid "boot storms" and ensure availability of published applications
* Give logged-in users ample time to log off before enforcing a reboot
* Provide logging and email alerting of when reboots occur or are delayed
* Change the behavior of the script on a per-server basis using Provisioning Services Personality Strings

Requirements:
* Windows PowerShell
* Citrix XenApp PowerShell SDK
* A XenApp load evalauator that prevents all user logins (i.e. reports a full load)

Provisioning Server Settings:
The behavior of the script can be modified on a per-server basis by setting the following Personality Strings in Provisioning Services.

String: Reboot_Email
Value:
0 = Does not send a reboot email
1 = Sends a reboot email

String: Reboot_Logging
Value:
0 = Does not log to text file. Windows event logging is not affected.
1 = Logs to text file. Windows event logging is not affected.

String: Wait_Override
Value:
0 = Normal reboot behavior
1 = Does not warn users or delay the reboot any longer than the number of seconds specified by $shutdownTimer. The reboot delay is not randomized so use with caution if setting this on multiple servers.

String: Reboot_Bypass
Value:
0 = Normal reboot behavior
1 = Aborts the reboot script

NB: Personality Strings are set at server boot time. If you change them on a provisioned server while it is up, you must reboot that server for the changes to take effect.