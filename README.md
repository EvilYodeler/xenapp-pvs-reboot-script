Summary:
This is a Windows PowerShell script that will:
* Reliably reboot Citrix XenApp servers provisioned using Citrix Provisioning Services
* Stagger reboots to avoid "boot storms" and ensure availability of published applications
* Give logged-in users ample time to log off before enforcing a reboot
* Provide logging and email alerting of when reboots occur or are delayed
* Change the behavior of the script on a per-server basis using Provisioning Services Personality Strings


Requirements:
* Windows PowerShell
* Citrix XenApp PowerShell SDK
* A XenApp load evalauator that prevents all user logins (i.e. reports a full load).


Usage:
1. Place the reboot.ps1 PowerShell script and sample configuration file (reboot-config.ps1.txt) into a directory on your provisioned image
2. Create a Windows scheduled task to launch the PowerShell script whenever you want reboots to begin (Execute "%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe" and add arguments "-File C:\pathtothescript\reboot.ps1") Make sure the account executing the script has administrative permissions on the server and that execution of unsigned PowerShell scripts is not restricted.
3. Rename or save reboot-config.ps1.txt as reboot-config.ps1. Modify this file according to your needs.
4. (Optional) Add Personality Strings to the services defined in Provisioning Services (see below).

Provisioning Server Settings:
The reboot behavior of individual servers can be modified on a per-server basis by setting the following Personality Strings in Provisioning Services.

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


FAQ:

Q. What happens when the script is executed?
A. At a high level, there are five basic steps:
1. Logons to the server are disabled
2. The script checks if any users are logged in. If none are, a reboot is initiated.
3. If users are logged in, they are presented with a pop-up notification that a reboot is imminent.
4. A reboot is initiated whenever all users log off or the reboot timer has expired, whichever comes first.
5. Logons to the server are re-enabled.

Q. Why not just randomly delay reboots using Windows Task Scheduler?
A. This has two disadvantages.
First, if there are no users logged into the server, the reboot may be unnecessarily delayed.
Second, any changes to the delay have to be made to the scheduled task which is stored on the provisioned image, whereas the reboot script configuration can be stored on a share or a persistent disk and modified more easily.

Q. Can I contribute?
A. Yes. If you're familiar with git, just push your changes and send me a pull request. Otherwise, email me at ben@benpiper.com.