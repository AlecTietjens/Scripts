------------
 How To Run
------------

Open command prompt as an administrator and use the following command: powershell -noexit \\pbms\automatedinstall\deployscript.ps1

After starting the script, it will ask you for your username and password; this is used for installing, as well as logging purposes. After
entering your credentials you will be asked what program you'd like to deploy, which computers you'd like to deploy to, and whether you want
a pre-results log created (a final results log will always be created).

----------
 Overview
----------

This script was designed to create a pre-results log (through an option) for software already installed on remote computers, deploy software, and then create a final
results log. This is important because it is very probable that some installs fail; the logs help you troubleshoot the failed deploys by listing
successes and failures.

--------------
 Requirements
--------------

1. The computer launching the script will need PSExec downloaded and installed.

2. Remote computers will need 'PSRemoting' enabled. (the PowerShell command 'Enable-PSRemoting' needs to be ran on each)

3. The program to be installed needs to be in the C:\PCMGMT folder of the remote computers.

--------------
 Known Errors
--------------
1.	Error:
		Receive the error “File … cannot be loaded. The file is not digitally signed. The script will not be executed on the system. “ 
		This means that the script is not trusted to be run on your system.
		
	Solution:
		Set-ExecutionPolicy RemoteSigned

