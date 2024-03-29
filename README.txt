HowTo:
To run full network scan, just double click on Inventory.vbs on a Windows domain member (sorry OSX and Linux users).
Output goes to the Reports folder. There will be no wait for return. IOW, while much faster running in parallel now, 
there will be no status report. Just open task manager and wait for any remaining instances of cscript or conhost to
end before reviewing reports.

If your reports don't show up, likely the problem is Windows Firewall. You will need to enable WMI. If firewall policy
is set by GPO, you'll need to do the following:

2003/XP:        Computer Configuration\Administrative Templates\Network\Network Connections\Windows Firewall\Domain Profile
                Enable the "Windows Firewall: Allow remote administration exception" policy.

2008R2/Vista/7: Computer Configuration\Policies\Windows Settings\Security Settings\Windows Firewall with Advanced Security\Windows Firewall with Advanced Security\Inbound Rules
                Right click, New Rule:
                Predefined, Windows Management Instrumentation (WMI), Windows Management Instrucmntation (WMI-In). 
                The other two are to taste, but not necessary, though I usually include them.
                Edit after creation and choose only Domain Profile (advanced tab).

===

Manual Run:
If a computer was offline, or otherwise unavailble (unplugged, bad switch, wireless down, whatever), or if you want to run
only on one PC, you can manually generate a report, or append to one by running the following command:
    cscript util\runinv.vbs [computername]
Coputer name is optional, if omitted, it will use the hostname of the machine it is run from.

===

Reports: Obvious!

===

Server2.4:  If this looks familiar, it is. Unfortunatly, it has been modified a lot (see the changelog in the Server2.4 folder).
Patches have been sent to the Sydi author, but I expect it'll be a while before they are even considered.

For now, this has been removed and replaced with an empty directory. You need to
use the branch from my github available at:
https://github.com/djlucas/sydi-server/tree/NetworkInventory - Just place the
contents into the Server2.4 direcotry for now.

===

util: This directory contains the inventory control script (runinv.vbs) and the software list (software.xml)

===

TODO:
Inventory.vbs: Cleanup duplicate objects (WShell.Script and Scripting.FilesystemObject)
Inventory.vbs: Provide a status bar to monitor child processes
Inventory.vbs: Add subnet IP scan (nmap?)
Inventory.vbs: Add pubic SNMP scanning for objects identified in IP scan (nmap capable directly?)
Inventory.vbs: Add index.html and include all recognized devices and links to existing html output
util/runinv.vbs: add state file for external status block reporting (add CL argument so that montioring can be done in Inventory.vbs)
util/runsnmpinv.vbs: create/add
Server2.4/Sydi-server.vbs: Cleanup duplicate objects (WShell.Script and Scripting.FilesystemObject)
Server2.4/Sydi-server.vbs: Cleanup duplicate code path for x86/x86_64 reg reads (add Sub for duplicate internal loops)


