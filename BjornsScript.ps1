<#====================================================================  Copyright © 2014, June. Bjørn Roalkvam  www.SharePointbjorn.com, bjorn80@gmail.com   I got sick of doing the manual tidying prior to starting a synchronization service,  So i scriptet the whole thing for you:-). I have a ton of experience starting the  evil User Profile Synchronization Service, have not yet found one I could not start!  You will want to run the script on the appserver that is running the User   Profile Synchronization service.  The script only targets the server you are running the script on   and does the following: -Disables the User profile Synchronization service (Even stuck ones!). -Deletes the awfull timerjob ProfileSynchronizationSetupJob. -Clears away all ForefrontManagerIdentity Certificates from the local machine  certificate stores. -Clears the SharePoint Confiugration Cache. -Gives you a choice to start the Synchronization service, it will ask you to input the   farmadmin account password.  Always test all scripts you find in an test environment prior to production:-),   you are a responsible SharePoint Administrator afterall! ====================================================================#>
 
# ===================================================================================
#Checks whether the script is running as admin, if not then starts as admin.
# ===================================================================================
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
 
{
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}
 
cls
Write-Host -f Cyan "Red ugly warning about set-executionPolicy.."
sleep 2
Write-Host -f Green "OK"
Write-Host ""
 
#Add sharepoint pssnapin if it doesnt exist:
if ( (Get-PSSnapin -Name microsoft.sharepoint.powershell -EA "SilentlyContinue") -eq $null )
{
    Add-PsSnapin microsoft.sharepoint.powershell
}
 
#Variable
$TempScript = "c:\StartSync.ps1" # This ps1-file will be created and then deleted at the end of the script.
 
#This script will always run on the local server:
$hostname = hostname
$server = get-spserver $hostname
$Serverdisplayname = $server.displayname
 
Write-Host -f Cyan "Verifying that the farmadmin account is set as local administrator on $Serverdisplayname.."
#Find the farmadmin account:
#$Farmaccount = (Get-SPFarm).DefaultServiceAccount.Name
#$admins = [adsi]'WinNT://localhost/administrators'
#$members = $admins.members() | foreach { ([adsi]$_).path.substring(8).replace('/','\') }
#$Answer = $members -contains $Farmaccount
 
#--Change suggested by Marcus Opel (http://devmarc.de/), thank you!
$objSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$objGroup = $objSID.Translate([System.Security.Principal.NTAccount])
$objGroupname = ($objGroup.Value).Split(“\”)[1]
 
$winNT = ‘WinNT://localhost/’ + $objGroupname
$farmAccount = (Get-SPFarm).DefaultServiceAccount.Name
$admins = [adsi]$winNT
$members = $admins.members() | foreach { ([adsi]$_).path.substring(8).replace(‘/’,’\’) }
$Answer = $members -contains $Farmaccount
#--
 
if($Answer -eq $False) {Write-Host -f Yellow "$Farmaccount is not local administrator, press any key to exit"; Read-Host; exit}
Write-Host -f Green "OK"
Write-Host ""
 
# ===================================================================================
# Stop User Profile Synchronization Service from any status to disabled
# ===================================================================================
Write-Host -f Cyan "Making sure that the User Profile Synchronization service is not running.."
$UPS = Get-SPServiceInstance -EA "SilentlyContinue" | Where {$_.TypeName -eq "User Profile Synchronization Service" -and $_.Server -match $server}
$UPS.Unprovision()
$ups.TypeName
$UPS.status
Write-Host -f Green "OK"
Write-Host ""
 
# ===================================================================================
# Deleting the timerjob ProfileSynchronizationSetupJob
# ===================================================================================
Write-Host -f Cyan "Making sure that the timerjob ProfileSynchronizationSetupJob does not exist.."
if(Get-SPTimerJob -EA "SilentlyContinue" | where {$_.Name -eq "ProfileSynchronizationSetupJob"})
{
$timerjob = Get-SPTimerJob -EA "SilentlyContinue" | where {$_.Name -eq "ProfileSynchronizationSetupJob"}
$timerjob.Delete()
}
Write-Host -f Green "OK"
Write-Host ""
 
# ===================================================================================
# Remove all ForefrontidentityManager certificates on server
# ===================================================================================
Write-Host -f Cyan "Removing Forefront Certificates from local machine certificate stores"
$allStoreNames = Get-ChildItem -Path cert:\LocalMachine | %{$_.name}
 
    foreach ($storename in $allStoreNames)
    {
        $store = New-Object System.Security.Cryptography.x509Certificates.x509Store($storename,"LocalMachine")
        $store.Open("ReadWrite")
 
        $certs = $store.Certificates | ? {$_.subject -like "*ForefrontIdentityManager*"}
        ForEach ($cert in $certs)
        {
          if($cert){$store.Remove($cert)}
        }
    $store.Close()
    }
    Write-Host -f Green "OK"
    Write-Host ""
 
# ===================================================================================
# Clear SharePoint confiuration cache
# ===================================================================================
 
#Detect SharePoint version
if((test-path "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\15") -eq $true)
{
$TimerName = "SharePoint Timer Service"
}
 
if((test-path "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\15") -ne $true)
{
$TimerName = "SharePoint 2010 Timer"
}
 
#Stop timer service
$SharePointimer = Get-Service $TimerName
$SharePointimer.Stop()
while($SharePointimer.Status -eq "Running")
{
write-host "Waiting for timer service to stop.."
sleep 2
$SharePointimer = Get-Service $TimerName
}
Write-Host -f Green "OK"
Write-Host ""
 
#Find and delete XML files in GUID + set cache.ini to 1.
$serverName = hostname
$XMLPath = "\\" + $serverName + "\c$\ProgramData\Microsoft\SharePoint\Config\" #The File path where the deploy package are located.
 
#Finding the newest Guid folder:
$FindGuidFolder = Get-ChildItem $XMLPath | ? { $_.PSIsContainer } | sort CreationTime -desc | select -f 1
$ActiveGuidFolder = $FindGuidFolder.name
 
#Deleting all XML files:
Write-Host -f Cyan "Clearing SharePoint configuration cache by deleting XML files.."
$OldNumberofXML = (Get-ChildItem ($XMLPath + $ActiveGuidFolder) | ?{$_.name -like "*xml*"}).count
$removeXML = Get-ChildItem ($XMLPath + $ActiveGuidFolder) | ?{$_.name -like "*xml*"} | % { Remove-Item $_.fullname -Force }
Set-Content (($XMLPath + $ActiveGuidFolder)+ "\" + "cache.ini") "1"
Write-Host -f Green "OK"
Write-Host ""
 
#Start timer service
$SharePointimer = Get-Service $TimerName
$SharePointimer.Start()
 
while($SharePointimer.Status -eq "Stopped")
{
Write-Host "Waiting for timer service to Start.."
sleep 2
$SharePointimer = Get-Service $TimerName
}
Write-Host -f Green "OK"
Write-Host ""
 
$NewNumberofXML = (Get-ChildItem ($XMLPath + $ActiveGuidFolder) | ?{$_.name -like "*xml*"}).count
 
#comparing xml count to previous count to make sure the cahche has been fully built up.
while($NewNumberofXML -lt $OldNumberofXML)
{
Write-Host "Waiting for new XML files to load into GUID.."
sleep 2
$NewNumberofXML = (Get-ChildItem ($XMLPath + $ActiveGuidFolder) | ?{$_.name -like "*xml*"}).count
}
Write-Host -f Green "OK"
write-host ""
Write-Host ""
Write-Host -f Green "Done Tidying"
Write-Host ""
Write-Host ""
sleep 4
write-Host "Enable the synchronization service now?"
$choice = read-host "<1> for YES and <2> for NO"
 
if($choice -eq "2"){Write-Host "exiting";sleep 2; exit}
 
# ===================================================================================
# Get farm password from user and insert it into the temp script that will run as farmadmin and start the synchronization service.
# ===================================================================================
$farmPassword = Read-Host "Type in password for $Farmaccount"
set-Content $TempScript ""
set-Content $TempScript ('$farmPassword = ' + '"' + $farmPassword + '"')
 
# ===================================================================================
# Create start-sync-script
# ===================================================================================
$Mainjob =
{
 
#Checks wheather the script is running as admin, if not then starts as admin.
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
 
{
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}
 
#Add snaping if it doesnt exist
if ( (Get-PSSnapin -Name microsoft.sharepoint.powershell -EA "SilentlyContinue") -eq $null )
{
    Add-PsSnapin microsoft.sharepoint.powershell
}
 
#Script runs on local server:
$hostname = hostname
$Farmaccount = (Get-SPFarm).DefaultServiceAccount.Name
 
#Store instances into variables:
$service1 = $(Get-SPServiceInstance | ? {$_.TypeName -match "User Profile Service" -and $_.Server -match $hostname})
$service2 = $(Get-SPServiceInstance | ? {$_.TypeName -match "User Profile Synchronization Service" -and $_.Server -match $hostname})
 
#Stop service instance
Write-Host -f Cyan "Stopping the User Profile Instance"
Stop-SPServiceInstance -Identity $service1.ID -Confirm:$false
 
while($service1.status -ne "Disabled")
{
Write-Host "Stopping the User Profile Service instance"
sleep 3
$service1 = $(Get-SPServiceInstance | ? {$_.TypeName -match "User Profile Service" -and $_.Server -match $hostname})
}
write-host -f Green "OK"
write-host ""
 
#Start service instance
Write-Host -f Cyan "Starting the User Profile Instance"
Start-SPServiceInstance -Identity $service1.ID 
 
while($service1.status -ne "Online")
{
Write-Host "Starting the User Profile Service instance"
sleep 3
$service1 = $(Get-SPServiceInstance | ? {$_.TypeName -match "User Profile Service" -and $_.Server -match $hostname})
}
write-host -f Green "OK"
write-host ""
 
#Start Synchronization service
Write-Host -f Cyan "Starting the User Profile Synchronization.."
$upsa = Get-SPServiceApplication | ?{$_.TypeName -like "*User Profile Serv*"}
 
$service2.Status = [Microsoft.SharePoint.Administration.SPObjectStatus]::Provisioning
$service2.IsProvisioned = $false
$service2.UserProfileApplicationGuid = $upsa.Id
$service2.Update()
$upsa.SetSynchronizationMachine($hostname, $service2.Id, $Farmaccount, $farmPassword)
Start-SPServiceInstance $service2
 
Write-Host ""
$t = 0
$service2 = $(Get-SPServiceInstance | ? {$_.TypeName -eq "User Profile Synchronization Service" -and $_.Server -match $hostname})
 
#get the Forefront Identity Manager Synchronization service to monitor its status
$syncservice = Get-Service FIMSynchronizationService
 
while(-not ($service2.Status -eq "Online"))
{
    sleep 10;
    Write-Host "Be Patient...You have only waited $t seconds"
    $service2 = $(Get-SPServiceInstance | ? {$_.TypeName -match "User Profile Synchronization Service" -and $_.Server -match $hostname})
    $t = $t + 10
    if($service2.Status -eq "Disabled"){Write-Host -f Yellow "Sync start has failed, press the anykey to exit";read-host;exit}
}
  $t = $t - 10
  write-host ""
Write-Host -f Green "OK - Synchronization Service is Online!"
sleep 3
write-host ""
iisreset
}
 
#Adding above script to the temp script.
Add-Content $TempScript $Mainjob
 
# ===================================================================================
# Run start-sync-script (temp script)
# ===================================================================================
$ScriptFile = $TempScript #$TempScript
$pw = convertto-securestring $farmpassword -asplaintext –force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $farmaccount, $pw
 
# Create a new process with UAC elevation
Start-Process $PSHOME\powershell.exe -Credential $cred -ArgumentList "-Command Start-Process $PSHOME\powershell.exe -ArgumentList `"'$scriptfile'`" -Verb Runas" -Wait
 
Write-Host ""
Write-Host "Wait for Sync script to finish.., press the anykey to remove temp script after"
Read-host
write-host "Clearing temp script.."
Remove-Item $TempScript
Write-Host -f Green "OK"
Read-host
exit