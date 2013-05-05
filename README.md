This is a Windows PowerShell script designed to achieve the following:
* Reboot Citrix XenApp servers provisioned using Citrix Provisioning Services
* Stagger reboots to avoid "boot storms" and ensure availability of published applications
* Give logged-in users ample time to log off before enforcing a reboot
* Provide logging and alerting of when reboots occur or are delayed
* Change the behavior of the script on a per-server basis using Personality Strings

Requirements:
* Windows PowerShell
* Citrix XenApp PowerShell SDK