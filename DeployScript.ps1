# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #  
 # This script is used to automate the deployment of provided applications to computers that already have the install file on their machine. There is a
 # README that provides details on running the script.
 #
 # Author:  Alec Tietjens
 # Date:    1/30/15
 # Version: 1.0
# ---------------------------------------------------------------------

# Computer list locations go here
# DISCLAIMER: the file paths used for the installations are relative to the remote computers, i.e. use the standard drive path
$mailComputers = Get-Content \\pbms\AutomatedInstall\ComputersMail.txt
$recepComputers = Get-Content \\pbms\AutomatedInstall\ComputersRecep.txt
$testComputers = Get-Content \\pbms\AutomatedInstall\ComputersTest.txt

# Application installation information goes here. The current data structure is an array with the first value is the name of the program, and the following 
# values will hold the install string used with psexec (which will be implemented in the install script)
$javaInstallStrings = { "Java" , 
    { "C:\PCMGMT\Java8U31_64.exe" , "/s" }.Invoke() ,
    { "C:\PCMGMT\Java8U31_32.exe" , "/s" }.Invoke() }.Invoke()  

$adobeRdrInstallString = { "Adobe Reader" , 
    { "C:\PCMGMT\AdbeRdr11010.exe" , "/q /s /sAll /rs /msi EULA_ACCEPT=YES AgreeToLicense=Yes RebootYesNo=No" }.Invoke() }.Invoke()

$scepInstallString = { "Endpoint Protection" , 
    { "C:\PCMGMT\scepinstall.exe" , "/s" }.Invoke() }.Invoke()

# # # # # # # # # Initialization Ends Here And Functions Begin # # # # # # # # # 

# Our only function - used to write the logs
function logSoftwareVersions 
{
    # Create the path & name for the log file - the format uses the application name, followed by user, followed by date (e.g., AdobeReader_v-altiet_Jan-27-15)
    $logFile = "\\pbms\automatedinstall\logs\" + ($selectedSoftware[0] -replace " ", "") + "_" + ($user -replace "\w+\\", "") + "_" + (Get-Date -Format "MMM-dd-yy") + ".log"

    # Results arrays used to store the computer and program objects
    $computerResults = @()
    $programResults = @()
    # Output string initialization - Includes header for this check/run through - args is the input (i.e., pre-results or results)
    $outputString = "* * * * * * * * * * * * * * * * * * * * * * * * * * $args For Deployment Of " + $selectedSoftware[0] + " * * * * * * * * * * * * * * * * * * * * * * * * * *`r`n`r`n"
    
    foreach($c in $selectedComputers)
    {
        echo $c

        # Create a new computer object for each computer to store results
        $result = New-Object System.Object
        $result | Add-Member -Type NoteProperty -Name ComputerName -Value $c
        $programs = @()

        # Store programs and versions found for the computer
        $filterString = "Name like '%" + $selectedSoftware[0] +"%'"
        $programsFound = Get-WmiObject -ComputerName $c -Class Win32_Product -Filter $filterString

        # Create program objects for each computer to be added to the computer result object. Also add newly discovered programs to the total programs list
        foreach($p in $programsFound) 
        {
            $program = New-Object System.Object
            $program | Add-Member -Type NoteProperty -Name Name -Value $p.Name
            $program | Add-Member -Type NoteProperty -Name Version -Value $p.Version

            # Add the program to the $programs array.. to be added to the computer results
            $programs += $program

            # This loop finds out if the discovered program is already a part of the total programs array. If not, it adds it to the list for total discoveries
            $found = 0
            foreach($pr in $programResults)
            {
                if(($pr.Name -eq $program.Name) -and ($pr.Version -eq $program.Version))
                {
                    $found = 1
                }
            }
            # If no match found, add to the totals array
            if($found -eq 0)
            {
                $programResults += $program
            }
        }

        # Finish the result object and add it to results
        $result | Add-Member -Type NoteProperty -Name Programs -Value $programs
        $computerResults += ($result)
    }

    # Loop through the program results so that the output is organized into what computers have each program and version.
    # GetEnumerator is used because $programResults is a hash table
    foreach($p in $programResults)
    {
        $program = $p.Name
        $version = $p.Version
        $outputString += "------- $program | Version: $version -------`r`n"

        # Loop through the computer results to see if there is a program/version match
        foreach($c in $computerResults)
        {
            $computer = $c.ComputerName

            # Loop through the programs found on the computer, in case multiple versions are found of a program (i.e., Java)
            foreach($cp in $c.Programs)
            {
                # If program and version match, add to the outputted list
                if(($cp.Name -eq $program) -and ($cp.Version -eq $version))
                {
                    $outputString += "$computer`r`n"
                }
            }
        }
        # Formatting
        $outputString += "`r`n"
    }

    # List computers that we were unable to obtain results for
    $outputString += "------- No Result -------`r`n"

    # List all computer that didn't return a program.. could be communication error or no install.. research into it
    foreach($c in $computerResults)
    {
        $computer = $c.ComputerName

        # If no programs are found, list them in the output - research into these computers later
        if($c.Programs.Count -eq 0)
        {
            $outputString += "$computer`r`n"
        }
    }

    Add-Content $logFile $outputString
}

# # # # # # # # # # # # Functions End Here # # # # # # # # # # # # # #

# Record the Start time
$startTime = Get-Date

# Script intro and gathering of user credentials
Write-Host "Deployment Script v1.0 - Please view README for instructions and details.`n"
Write-Host "Be aware that this deployment could take up to 8 hours..`n"
$user = Read-Host "Please enter your domain\username: "
$password = Read-Host "`nPlease enter your password: " -AsSecureString

# User options for software
while(!$deployOption) 
{
    $deployOption = Read-Host "`nWould you like to deploy Java (1), Adobe Reader (2), or SCEP (3)? Please enter only the number corresponding to the program. "

    # Check against input for options 1-3. Set string $deployOption to empty if input doesn't match criteria so that user is prompted again
    if($deployOption -notmatch "^[1-3]{1}$") 
    {
        $deployOption = ""
        Write-Host -ForegroundColor Red "`nInvalid input!"
    }
}

# Sets $selectedSoftware to user's choice
switch($deployOption) 
{
    1 {$selectedSoftware = $javaInstallStrings}    # Java case
    2 {$selectedSoftware = $adobeRdrInstallString} # Adobe Reader case
    3 {$selectedSoftware = $scepInstallString}     # SCEP case
}

# User options for computers to be deployed to
while(!$computersOption) 
{
    $computersOption = Read-Host "`nWould you like to deploy to Reception (1), Mail (2), Both Reception and Mail (3), or Test (4)? Please enter the corresponding number. "

    # Check against input for options 1-4. Set string $computersSelected to empty if input doesn't match criteria so that user is prompted again
    if($computersOption -notmatch "^[1-4]{1}$") 
    {
        $computersOption = ""
        Write-Host -ForegroundColor Red "`nInvalid input!"
    }
}

# Sets $selectedComputers to user's choice
switch($computersOption)
{
    1 {$selectedComputers = $recepComputers}                  # Reception computers case
    2 {$selectedComputers = $mailComputers}                   # Mail computers case
    3 {$selectedComputers = $recepComputers + $mailComputers} # Mail and Reception case
    4 {$selectedComputers = $testComputers}                   # Test computers case
}

# Pre-results or no?
while(!$preresultsOption)
{
    # See if user would like to run a pre-results log
    $preresultsOption = Read-Host "`nWould you like to create a preresults log before the deployment? This could add up to a few hours. [y/n] "
    
    # Check to see if user provided a valid "yes" answer
    if($preresultsOption -match "^y{1}$" -or $preresults -match "^yes{1}$")
    {
        logSoftwareVersions "Pre-Results"
    }
    # Check for valid "no" answer
    elseif($preresultsOption -match "^n{1}$" -or $preresults -match "^no{1}$")
    {
        break;
    }
    else { $preresultsOption = "" } # Yes or no was not matched.. prompt again
}

# Run the install with PSExec on the selected computers
foreach($c in $selectedComputers)
{
    # Loop through the software options for the selected software, in case multiple installs requested for software.. i.e., Java
    for($i = 1; $i -lt $selectedSoftware.Count; $i++)
    {
        $program = $selectedSoftware[$i][0]
        $arguments = $selectedSoftware[$i][1]
        psexec -s \\$c -u $user -p $password $program $arguments
    }
}

# Call for final log of software
logSoftwareVersions "Final Results"