HowTo:
To run full network scan, just double click on Inventory.vbs on a Windows domain member
(sorry OSX and Linux users).
Output goes to the Reports folder. There will be no wait for return. IOW, while much faster
running in parallel now, there will be no status report. Just open task manager and wait for
any remaining instances of cscript or conhost to end before reviewing reports.

If your reports don't show up, likely the problem is Windows Firewall. You will need to enable
WMI. If firewall policy is set by GPO, you'll need to do the following:

2003/XP:        Computer Configuration\Administrative Templates\Network\Network Connections\Windows Firewall\Domain Profile
                Enable the "Windows Firewall: Allow remote administration exception" policy.

2008R2/Vista/7: Computer Configuration\Policies\Windows Settings\Security Settings\Windows Firewall with Advanced Security\Windows Firewall with Advanced Security\Inbound Rules
                Right click, New Rule:
                Predefined, Windows Management Instrumentation (WMI), Windows Management Instrucmntation (WMI-In). 
                The other two are to taste, but not necessary, though I usually include them.
                Edit after creation and choose only Domain Profile (advanced tab).

Additionally, our monitoring software requires the firewall open for the network probe, so this
covers it nicely if you will be running from the netowrk probe machine.
Create a new rule, choose:
                Custom->All programs->Any->local:Any,remote:These IP addresses (insert DC/Probe IPs here)->
                Allow->Only Domain->Allow DC/Probe connections->Finish

These can all be done in the same GPO.

===

Manual Run:
If a computer was offline, or otherwise unavailble (unplugged, bad switch, wireless down, whatever),
or if you want to run only on one PC, you can manually generate a report, or append to one by running
the following command:
    cscript util\runinv.vbs [computername]
Coputer name is optional, if omitted, it will use the hostname of the machine it is run from.
IOW, just double click on it to run for the current machine.
===

Reports: Obvious!

===

sydi-server:  Patches have been sent to the Sydi author for review, and hopefully inclusion in the
next version. For now, just use my copy.

===

util: This directory contains the inventory control script (runinv.vbs) and the software list (software.xml)

===

TODO:
Inventory.vbs: Cleanup duplicate objects (WShell.Script and Scripting.FilesystemObject)
Inventory.vbs: Provide a status bar to monitor child processes
Inventory.vbs: Add subnet IP scan (nmap?)
Inventory.vbs: Add pubic SNMP scanning for objects identified in IP scan (nmap
               capable directly?)
Inventory.vbs: Add index.html and include all recognized devices and links to existing
               html output
util/runinv.vbs: add state file for external status block reporting (add CL argument
                 so that montioring can be done in Inventory.vbs)
util/runinv.vbs: add expected version output to NeedsUpdate.txt report
util/runsnmpinv.vbs: create/add
sydi-server/sydi-server.vbs: Cleanup detection of Windows 10 "Builds" - add case for future
sydi-server/sydi-server.vbs: Cleanup duplicate objects
                             (WShell.Script and Scripting.FilesystemObject)
sydi-server/sydi-server.vbs: Cleanup duplicate code path for x86/x86_64 reg reads
                             (add Sub for duplicate internal loops)
sydi-server/*: send updates for inclusion in 2.5 (github, will happen soon)

