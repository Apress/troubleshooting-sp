#####################################################
# This script replicates most of the functionality found in the SharePoint Products Configuration Wizard with the EXCEPTION of the USER PROFILE SERVICE#####################################################
Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue

## Settings you may want to change ##
$databaseServerName = "SharePointSQL" #assumes you're using a SQL Alias configured with cliconfg.exe
$searchServerName = "2010APP" #Front end Server that will run central admin, the server you’re on right now
$saAppPoolName = "SharePoint Hosted Services"
$appPoolUserName = "Contoso\2010svcapps" #This is the service application pool account it is not the farm admin account for Timer and Central admin, sometimes calle#d the farm account, it is not the setup account, or install account

$ssaAppPoolName = "SharePoint Search Service Application Pool"
$SearchappPoolUserName = "Contoso\2010Search"


# running this script

## Service Application Service Names ##
$accesssSAName = "Access Services"
$bcsSAName = "Business Data Connectivity Service"
$excelSAName = "Excel Services Application"
$metadataSAName = "Managed Metadata Web Service"
$performancePointSAName = "PerformancePoint Service"
$searchSAName = "SharePoint Server Search"
$stateSAName = "State Service"
$secureStoreSAName = "Secure Store Service"
$usageSAName = "Usage and Health Data Collection Service"
$visioSAName = "Visio Graphics Service"
$WebAnalyticsSAName = "Web Analytics Service"
$WordAutomationSAName = "Word Automation Services"

$saAppPool = Get-SPServiceApplicationPool -Identity $saAppPoolName -EA 0
if($saAppPool -eq $null)
{
Write-Host "Creating Service Application Pool…"

$appPoolAccount = Get-SPManagedAccount -Identity $appPoolUserName -EA 0
if($appPoolAccount -eq $null)
{
Write-Host "Please supply the password for the Service Account…"
$appPoolCred = Get-Credential $appPoolUserName
$appPoolAccount = New-SPManagedAccount -Credential $appPoolCred -EA 0
}

$appPoolAccount = Get-SPManagedAccount -Identity $appPoolUserName -EA 0

if($appPoolAccount -eq $null)
{
Write-Host "Cannot create or find the managed account $appPoolUserName, please ensure the account exists."
Exit -1
}

New-SPServiceApplicationPool -Name $saAppPoolName -Account $appPoolAccount -EA 0 > $null

}

Write-Host "Creating Usage Service and Proxy…"
$serviceInstance = Get-SPUsageService
New-SPUsageApplication -Name $usageSAName -DatabaseServer $databaseServerName -DatabaseName "Usage" -UsageService $serviceInstance > $null

Write-Host "Creating Access Services and Proxy…"
New-SPAccessServiceApplication -Name $accesssSAName -ApplicationPool $saAppPoolName > $null
Get-SPServiceInstance | where-object {$_.TypeName -eq "Access Database Service"} | Start-SPServiceInstance > $null

Write-Host "Creating BCS Service and Proxy…"
New-SPBusinessDataCatalogServiceApplication -Name $bcsSAName -ApplicationPool $saAppPoolName -DatabaseServer $databaseServerName -DatabaseName "BusinessDataCatalog" > $null

Get-SPServiceInstance | where-object {$_.TypeName -eq "Business Data Connectivity Service"} | Start-SPServiceInstance > $null

Write-Host "Creating Excel Service…"
New-SPExcelServiceApplication -name $excelSAName –ApplicationPool $saAppPoolName > $null

Set-SPExcelFileLocation -Identity "http://" -ExcelServiceApplication $excelSAName -ExternalDataAllowed 2 -WorkbookSizeMax 10 -WarnOnDataRefresh:$true

Get-SPServiceInstance | where-object {$_.TypeName -eq "Excel Calculation Services"} | Start-SPServiceInstance > $null

Write-Host "Creating Metadata Service and Proxy…"
New-SPMetadataServiceApplication -Name $metadataSAName -ApplicationPool $saAppPoolName -DatabaseServer $databaseServerName -DatabaseName "Metadata" > $null

New-SPMetadataServiceApplicationProxy -Name "$metadataSAName Proxy" -DefaultProxyGroup -ServiceApplication $metadataSAName > $null

Get-SPServiceInstance | where-object {$_.TypeName -eq "Managed Metadata Web Service"} | Start-SPServiceInstance > $null

Write-Host "Creating Performance Point Service and Proxy…"
New-SPPerformancePointServiceApplication -Name $performancePointSAName -ApplicationPool $saAppPoolName -DatabaseServer $databaseServerName -DatabaseName "PerformancePoint" > $null

New-SPPerformancePointServiceApplicationProxy -Default -Name "$performancePointSAName Proxy" -ServiceApplication $performancePointSAName > $null

Get-SPServiceInstance | where-object {$_.TypeName -eq "PerformancePoint Service"} | Start-SPServiceInstance > $null

##START SEARCH

$ssaAppPool = Get-SPServiceApplicationPool -Identity $ssaAppPoolName -EA 0
if($ssaAppPool -eq $null)
{
Write-Host "Creating Search Service Application Pool…"

$SearchappPoolAccount = Get-SPManagedAccount -Identity $SearchappPoolUserName -EA 0
if($SearchappPoolAccount -eq $null)
{
Write-Host "Please supply the password for the Service Account…"
$ssappPoolCred = Get-Credential $SearchappPoolUserName
$SearchappPoolAccount = New-SPManagedAccount -Credential $ssappPoolCred -EA 0
}

$SearchappPoolAccount = Get-SPManagedAccount -Identity $SearchappPoolUserName -EA 0

if($appPoolAccount -eq $null)
{
Write-Host "Cannot create or find the managed account $SearchappPoolUserName, please ensure the account exists."
Exit -1
}

New-SPServiceApplicationPool -Name $ssaAppPoolName -Account $SearchappPoolAccount -EA 0 > $null

}



## Search Specifics, we are single server farm ##

$searchServerName = (Get-ChildItem env:computername).value

$serviceAppName = "Enterprise Search Services"

$searchDBName = "Search"


Write-Host "Creating Search Service and Proxy…"
Write-Host " Starting Services…"
Start-SPEnterpriseSearchServiceInstance $searchServerName
Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance $searchServerName
 
Write-Host " Creating Search Application…"
$searchApp = New-SPEnterpriseSearchServiceApplication -Name $searchSAName -ApplicationPool $ssaAppPoolName -DatabaseServer $databaseServerName -DatabaseName $searchDBName
$searchInstance = Get-SPEnterpriseSearchServiceInstance $searchServerName
 
Write-Host " Creating Administration Component…"
$searchApp | Get-SPEnterpriseSearchAdministrationComponent | Set-SPEnterpriseSearchAdministrationComponent -SearchServiceInstance $searchInstance
 
#Crawl
Write-Host " Creating Crawl Component…"
$InitialCrawlTopology = $searchApp | Get-SPEnterpriseSearchCrawlTopology -Active
$CrawlTopology = $searchApp | New-SPEnterpriseSearchCrawlTopology
$CrawlDatabase = ([array]($searchApp | Get-SPEnterpriseSearchCrawlDatabase))[0]
$CrawlComponent = New-SPEnterpriseSearchCrawlComponent -CrawlTopology $CrawlTopology -CrawlDatabase $CrawlDatabase -SearchServiceInstance $searchInstance
$CrawlTopology | Set-SPEnterpriseSearchCrawlTopology -Active
 
Write-Host -ForegroundColor white " Waiting for the old crawl topology to become inactive" -NoNewline
do {write-host -NoNewline .;Start-Sleep 6;} while ($InitialCrawlTopology.State -ne "Inactive")
$InitialCrawlTopology | Remove-SPEnterpriseSearchCrawlTopology -Confirm:$false
Write-Host
 
#Query
Write-Host " Creating Query Component…"
$InitialQueryTopology = $searchApp | Get-SPEnterpriseSearchQueryTopology -Active
$QueryTopology = $searchApp | New-SPEnterpriseSearchQueryTopology -Partitions 1
$IndexPartition= (Get-SPEnterpriseSearchIndexPartition -QueryTopology $QueryTopology)
$QueryComponent = New-SPEnterpriseSearchQuerycomponent -QueryTopology $QueryTopology -IndexPartition $IndexPartition -SearchServiceInstance $searchInstance
$PropertyDatabase = ([array]($searchApp | Get-SPEnterpriseSearchPropertyDatabase))[0]
$IndexPartition | Set-SPEnterpriseSearchIndexPartition -PropertyDatabase $PropertyDatabase
$QueryTopology | Set-SPEnterpriseSearchQueryTopology -Active
 
Write-Host " Creating Proxy…"
$searchAppProxy = New-SPEnterpriseSearchServiceApplicationProxy -Name "$searchSAName Proxy" -SearchApplication $searchSAName > $null
 
#####END SEARCH
 

Write-Host "Creating State Service and Proxy…"
New-SPStateServiceDatabase -Name "StateService" -DatabaseServer $databaseServerName | New-SPStateServiceApplication -Name $stateSAName | New-SPStateServiceApplicationProxy -Name "$stateSAName Proxy" -DefaultProxyGroup > $null

Write-Host "Creating Secure Store Service and Proxy…"
New-SPSecureStoreServiceapplication -Name $secureStoreSAName -Sharing:$false -DatabaseServer $databaseServerName -DatabaseName "SecureStoreServiceApp" -ApplicationPool $saAppPoolName -auditingEnabled:$true -auditlogmaxsize 30 | New-SPSecureStoreServiceApplicationProxy -name "$secureStoreSAName Proxy" -DefaultProxygroup > $null

Get-SPServiceInstance | where-object {$_.TypeName -eq "Secure Store Service"} | Start-SPServiceInstance > $null

Write-Host "Creating Visio Graphics Service and Proxy…"
New-SPVisioServiceApplication -Name $visioSAName -ApplicationPool $saAppPoolName > $null

New-SPVisioServiceApplicationProxy -Name "$visioSAName Proxy" -ServiceApplication $visioSAName > $null

Get-SPServiceInstance | where-object {$_.TypeName -eq "Visio Graphics Service"} | Start-SPServiceInstance > $null

Write-Host "Creating Web Analytics Service and Proxy…"
$stagerSubscription = ""
$reportingSubscription = ""
New-SPWebAnalyticsServiceApplication -Name $WebAnalyticsSAName -ApplicationPool $saAppPoolName -ReportingDataRetention 20 -SamplingRate 100 -ListOfReportingDatabases $reportingSubscription -ListOfStagingDatabases $stagerSubscription > $null

New-SPWebAnalyticsServiceApplicationProxy -Name "$WebAnalyticsSAName Proxy" -ServiceApplication $WebAnalyticsSAName > $null

Get-SPServiceInstance | where-object {$_.TypeName -eq "Web Analytics Web Service"} | Start-SPServiceInstance > $null

Get-SPServiceInstance | where-object {$_.TypeName -eq "Web Analytics Data Processing Service"} | Start-SPServiceInstance > $null

Write-Host "Creating Word Conversion Service and Proxy…"
New-SPWordConversionServiceApplication -Name $WordAutomationSAName -ApplicationPool $saAppPoolName -DatabaseServer $databaseServerName -DatabaseName "WordAutomation" -Default > $null

Get-SPServiceInstance | where-object {$_.TypeName -eq "Word Automation Services"} | Start-SPServiceInstance > $null
############################################## End Script



#Now proceed to manually configuring your service applications (e.g. the Secure Store Service for Excel Services, Visio graphics, and performance point. The managed meta data service #for a content type hub)