<# ==============================================================
//
// Microsoft provides programming examples for illustration only,
// without warranty either expressed or implied, including, but not
// limited to, the implied warranties of merchantability and/or
// fitness for a particular purpose.
//
// This sample assumes that you are familiar with the programming
// language being demonstrated and the tools used to create and debug
// procedures. Microsoft support professionals can help explain the
// functionality of a particular procedure, but they will not modify
// these examples to provide added functionality or construct
// procedures to meet your specific needs. If you have limited
// programming experience, you may want to contact a Microsoft
// Certified Partner or the Microsoft fee-based consulting line at
// (800) 936-5200 [Call: (800) 936-5200] .
//
// For more information about Microsoft Certified Partners, please
// visit the following Microsoft Web site:
// https://partner.microsoft.com/global/30000104
//
// Author: Russ Maxwell (russmax@microsoft.com)
//
// ———————————————————- #>

##Version 1.5 – Date 3-23-17##

[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
Add-PSSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue
Start-SPAssignment -Global

#############
##Variables##
#############
$global:ulsPath = (get-spdiagnosticconfig).LogLocation
$global:servs = (get-spfarm).servers | ?{$_.Role -ne "Invalid"}
$global:keepCount = 0
#################################
#Function to set custom log path#
#################################
function custLogPath()
{
$global:ulsPath = $global:ulsPath -replace ":", "$"
$localPath = "\\" + $env:ComputerName + "\" + $global:ulsPath
$resTemp = get-childitem -path $localPath | ?{$_.Extension -eq ".log"}
return $resTemp
}

 

#########################################
#InnerFunction to retrieve and copy logs#
#########################################
function innerGrabULS($temsrv)
{
$partPath = "\\" + $srv.name + "\" + $global:ulsPath + "\*.*"
$srvInclude = $srv.name + "*.log"
$sortedFiles = get-childitem -path $partPath -Include $srvInclude | sort-object LastWriteTime -descending
$filePath = $sortedFiles[0].FullName
$fileName = $sortedFiles[0].Name

try
{
Copy-Item -Path $filePath -Destination $temdestPath
$fulldestPath = $temdestPath + "\" + $fileName

if(Test-Path $fulldestPath)
{$Global:keepCount++}

else
{
Write-Host "Unable to copy latest ULS file from the following Server: " + $srv.Name -ForegroundColor Yellow
Write-Host "You will need to go retrieve the latest ULS log manually" -ForegroundColor Yellow
Write-Host
}
}

catch [Exception]
{
Write-Host “Exception Caught: ” $_.Exception -ForegroundColor Red
Write-Host "Error attempting to copy file from Server: " + $srv.Name -ForegroundColor Red
Write-Host
}
}

 

#####################################
#Function to retrieve and copy logs#
#####################################
function grabULS($temdestPath)
{
#$srvCount = $temSrvs.count
if($global:servs.gettype().tostring() -eq "System.Object[]")
{
$srvCount = $global:servs.count

foreach($srv in $global:servs)
{innerGrabULS $srv}
}

elseif($global:servs.gettype().tostring() -eq "Microsoft.SharePoint.Administration.SPServer")
{
#We're dealing with a single server farm#
innerGrabULS
$srvCount = 1
}

if($keepCount -eq $srvCount)
{return, 1}

else
{return, 2}
}

#########################
##Function to clear log##
#########################
function clearLog($temfinalRes)
{
if($temfinalRes -eq 1)
{
Write-Host "Latest ULS Logs have been copied" -ForegroundColor Green
Write-Host "Resetting Log Level back to Default"
Clear-SPLogLevel
}

else
{
Write-Host "Either no files or a partial of ULS log files copied" -ForegroundColor Yellow
Write-Host "Please inspect the destination directory for more details"
Write-Host "Resetting Log Level back to Default"
Clear-SPLogLevel
}
}

 

 

######################
##Script Starts Here##
######################

######################
#Get Destination Path#
######################
Write-Host "Enter a folder path where you want the ULS files copied"
$outputDir = Read-Host "(For Example: c:\logs\)"

if(test-path -Path $outputDir)
{Write-Host}

else
{
Write-Host "The path you provided could not be found" -foregroundcolor Yellow
Write-Host "Path Specified: " $outputDir -ForegroundColor Yellow
Write-Host
$outputDir = Read-Host "Enter a folder path where you want the ULS files copied (For Example: c:\logs\)"
$checkPath = test-path $outputDir

if($checkPath -ne $true)
{
Write-Host "Path was not found - Exiting Script" -ForegroundColor Yellow
Return
}

else
{Write-Host "Path is now valid and will continue"}

}

 

########################################
#Get SharePoint Servers and SP Version##
########################################

$spVersion = (Get-PSSnapin Microsoft.Sharepoint.Powershell).Version.Major

if((($spVersion -ne 14) -and ($spVersion -ne 15) -and ($spVersion -ne 16)))
{
Write-Host "Supported version of SharePoint not Detected" -ForegroundColor Yellow
Write-Host "Script is supported for SharePoint 2010, 2013, or 2016" -ForegroundColor Yellow
Write-Host "Exiting Script" -ForegroundColor Yellow
Return
}

if($spVersion -eq 14)
{
$defPathTemp = "%CommonProgramFiles%\Microsoft Shared\Web Server Extensions\14\Logs\"
if($global:ulsPath -eq $defPathTemp)
{
$global:ulsPath = "\c$\" + "program files\common files\microsoft shared\web server extensions\14\logs"
$localPath = "\\" + $env:ComputerName + $global:ulsPath
$resTemp = get-childitem -path $localPath | ?{$_.Extension -eq ".log"}
}

else
{$resTemp = custLogPath}
}

elseif($spVersion -eq 15)
{
$defPathTemp = "%CommonProgramFiles%\Microsoft Shared\Web Server Extensions\15\Logs\"
if($global:ulsPath -eq $defPathTemp)
{
$global:ulsPath = "\c$\" + "program files\common files\microsoft shared\web server extensions\15\logs"
$localPath = "\\" + $env:ComputerName + $global:ulsPath
$resTemp = get-childitem -path $localPath | ?{$_.Extension -eq ".log"}
}

else
{$resTemp = custLogPath}
}

elseif($spVersion -eq 16)
{
$defPathTemp = "%CommonProgramFiles%\Microsoft Shared\Web Server Extensions\16\Logs\"
if($global:ulsPath -eq $defPathTemp)
{
$global:ulsPath = "\c$\" + "program files\common files\microsoft shared\web server extensions\16\logs"
$localPath = "\\" + $env:ComputerName + $global:ulsPath
$resTemp = get-childitem -path $localPath | ?{$_.Extension -eq ".log"}
}

else
{$resTemp = custLogPath}
}

if($resTemp -eq $null)
{
Write-Host "ULS Log directory is invalid or no log files are present.  Exiting Script" -foregroundcolor Red
Return
}

 

############################
#crank SPLogging to Verbose#
############################
try
{
Write-Host "Turning up Diagnostic Logging to Verbose"
set-sploglevel -TraceSeverity Verbose
Write-Host "Verbose Logging now Enabled"
}

catch [Exception]
{
Write-Host “Exception Caught: ” $_.Exception -ForegroundColor Red
Write-Host
Write-Host "Error attempting to set ULS Tracing to Verbose" -ForegroundColor Red
#Clearing Just in Case#
Clear-SPLogLevel -ErrorAction SilentlyContinue

Write-Host "Exiting Script" -ForegroundColor Red
Return
}

 

###################################
#create new ULS Log on all servers#
###################################
if($global:servs.gettype().tostring() -eq "System.Object[]")
{
foreach($srv in $global:servs)
{
Write-Host "Creating New ULS Log on Server: " $srv
$service = get-service -ComputerName $srv.Name -Name "SPTraceV4"
if($service){$service.ExecuteCommand(129)}
}
}

elseif($global:servs.gettype().tostring() -eq "Microsoft.SharePoint.Administration.SPServer")
{
Write-Host "Creating New ULS Log on Server: " $global:servs
$service = get-service -ComputerName $srv.Name -Name "SPTraceV4"
if($service){$service.ExecuteCommand(129)}
}

Write-Host "New ULS Logs Created for every SharePoint Server in the farm" -ForegroundColor Green
Write-Host

 

######################################
#Reproduce the Issue and Collect Logs#
######################################
Write-Host "Keep this window open and reproduce the issue!"
Write-Host "After reproducing issue press 1 and enter key!"
Write-Host
$val = Read-Host

if($val -eq 1)
{
Write-Host "Copying files into Destination Provided"
$finalRes = grabULS $outputDir
clearLog $finalRes
Write-Host "Operation Complete - Exiting Script" -ForegroundColor Green
Invoke-Item $outputDir
}

else
{
Write-Host "You pressed a different key" -ForegroundColor Yellow
Write-Host
Write-Host "Try Again: After reproducing issue press 1 and enter key!"
Write-Host
$val = Read-Host

if($val -eq 1)
{
Write-Host "Copying files into Destination Provided"
$finalRes = grabULS $outputDir
clearLog $finalRes
Write-Host "Operation Complete - Exiting Script" -ForegroundColor Green
Invoke-Item $outputDir
}

else
{
Write-Host "This is the second attempt and a wrong key was entered" -foregroundcolor Yellow
Write-Host "Resetting Logging Level back to default and exiting script"-ForegroundColor Yellow
Clear-SPLogLevel
Return
}
}

Stop-SPAssignment –Global