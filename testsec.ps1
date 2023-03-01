function Get-AzLogin {
  <#
      .SYNOPSIS
          Checks AZ login status and account
      .DESCRIPTION
          Use this module to check Azure PowerShell login status and make sure that user is logged in.
      .EXAMPLE
          Get-AzLogin
  #>

  Write-Host "[Get-AzLogin] Checking Azure PowerShell Login... " -NoNewline
  # Check if logged in to Azure PowerShell
  $AccessToken = Get-AzAccessToken -ErrorAction SilentlyContinue
  if (!$AccessToken) {
      Write-Host "Login needed"
      try {
          # Login-AzAccount -ErrorAction stop > Out-Null
          Connect-AzAccount 
      }
      catch
      {
          throw "Could not login to Azure"
      }
  } else {
          Write-Host "Already logged in"
  }
}

Write-Host ""

Get-AzLogin

Write-Host ""

function AzSecurityAssessment ($subscrId) {
<#
Equals          Method     bool Equals(System.Object obj)
GetHashCode     Method     int GetHashCode()
GetType         Method     type GetType()
ToString        Method     string ToString()
AdditionalData  Property   System.Collections.Generic.Dictionary[string,string] AdditionalData {get;set;}
DisplayName     Property   string DisplayName {get;set;}
Id              Property   string Id {get;set;}
Name            Property   string Name {get;set;}
ResourceDetails Property   Microsoft.Azure.Commands.Security.Models.Assessments.PSSecurityResourceDetails ResourceDetai…
Status          Property   Microsoft.Azure.Commands.Security.Models.Assessments.PSSecurityAssessmentStatus Status {get;…
#>

Write-Host "AzSecurityAssessment: $subscrId"
  #$objObj = Get-AzSecurityAssessment | Select-Object Id, DisplayName -ExpandProperty 
  $query = @"
SecurityResources
| where type == 'microsoft.security/assessments'
| where subscriptionId == "$subscrId"
| where properties.status.code !in ("Healthy","NotApplicable")
| where properties.metadata.severity !in ("Low","Medium")
| project properties.status.firstEvaluationDate,properties.status.code,properties.displayName,properties.metadata.severity,properties.resourceDetails.Id,properties.links.azurePortal
| summarize count() by tostring(properties_metadata_severity),tostring(properties_displayName)
| order by ['count_'] desc
"@

  $results = Search-AzGraph -Query $query

  $reportObj = @()
#iterate through each finding, projecting details including the affected resource ID
$results | ForEach-Object {
    #Query is updated to look at a different finding each pass through the loop
    $findingQuery = @"
SecurityResources
| where type == 'microsoft.security/assessments'
| where subscriptionId == "$subscrId"
| where properties.status.code !in ("Healthy","NotApplicable")
| where properties.displayName == `"$($_.properties_displayName)`"
| project properties.displayName,properties.status.code,properties.status.firstEvaluationDate,properties.resourceDetails.Id,properties.links.azurePortal
"@

    #Search-AzGraph will only return the top 100 results by default. A maximum of 1000 results can be specified
    $findingResults = Search-AzGraph -Query $findingQuery -First 1000
    #Now iterate through each affected resource
    $findingResults | Foreach-Object {
        #Query is updated to look at each affected resource for each finding
        $resourceQuery = @"
Resources
| where id =~ `"$($_.properties_resourceDetails_Id)`"
| mv-expand tags=tags
| project tags
"@
$resourceQuery
        $resourceDetails = Search-AzGraph -query $resourceQuery
        #Custom object captures all relevant data about the finding and affected resource
        $resultObj = [PSCustomObject]@{
            AllTags = $resourceDetails.Tags
            Type = $resourceDetails.Tags.'type' | Where-Object {$_ -ne $null}
            Team = $resourceDetails.Tags.'team' | Where-Object {$_ -ne $null}
            Contact = $resourceDetails.Tags.'adminContact' | Where-Object {$_ -ne $null}
            ResourceId = $_.properties_resourceDetails_Id
            Finding = $_.properties_displayName
            FindingLink = $_.properties_links_azurePortal
            DateIdentified = $_.properties_status_firstEvaluationDate
        }
        $reportObj += $resultObj
    }
    $reportObj | Export-Csv defender2.csv -Append -NoTypeInformation -Force 
} 

}

function parser ($resId) {
$rsId = $resId
$rsId = $rsId + "'"
$rsId = $rsId -replace "^/","'"
$rsId = $rsId -replace "/","'='" 

$charCount = ($rsId.ToCharArray() -eq "=").Count
Write-Host "$charCount - $rsId"

#$rsIdx = ($rsId | Select-String "=" -AllMatches).Matches.Index

<#
$long_word = "Consequences"
-join ($long_word -split '(.{2})').ForEach({$_[0..0]})
foreach($rspos in $rsIdx) {
  $rspos
  $rsId = $rsId -replace "(?<=^.{$rspos}).",","
  Write-Host $rsId
}#>

}

function parseGroupAndName{
  param (
    [string]$subname,
     [string]$subid,
     [string]$resourceID,
     [string]$additionalData,
     [string]$resourceDetails,
     [string]$status
  )

 $hash = $null
 $hash = @{}
 $array = $resourceID.Split('/') 
 
 if($subid) { $hash.add("SubscriptionID", $subid) } else { $hash.add("SubscriptionID", "") }
 if($subname) { $hash.add("SubscriptionName", $subname) } else { $hash.add("SubscriptionName", "") }

 $indexA = 0..($array.Length -1) | where {$array[$_] -eq 'resourcegroups'}
 if($indexA) { $hash.add("ResourceGroups", $array.get($indexA+1)) } else { $hash.add("ResourceGroups","") } 
 
 if($resourceID) { $hash.add("ResourceID", $resourceID) } else { $hash.add("ResourceID", "") }

 $indexB = 0..($array.Length -1) | where { $array[$_] -eq 'virtualnetworks' }
 if($indexB) { $hash.add("VirtualNetworks", $array.get($indexB+1)) } else { $hash.add("VirtualNetworks","") }
 $indexC = 0..($array.Length -1) | where { $array[$_] -eq 'subnets' } 
 if($indexC) { $hash.add("Subnets", $array.get($indexC+1)) } else { $hash.add("Subnets","") }
 $indexD = 0..($array.Length -1) | where { $array[$_] -eq 'service' }
 if($indexD) { $hash.add("Service", $array.get($indexD+1)) } else { $hash.add("Service","") }
 $indexE = 0..($array.Length -1) | where { $array[$_] -eq 'virtualMachines' }
 if($indexE) { $hash.add("VMs", $array.get($indexE+1))  } else { $hash.add("VMs","") }
 $indexF = 0..($array.Length -1) | where { $array[$_] -eq 'vaults' }
 if($indexF) { $hash.add("Vaults", $array.get($indexF+1))  } else { $hash.add("Valuts","") }
 $indexG = 0..($array.Length -1) | where { $array[$_] -eq 'sites' }
 if($indexG) { $hash.add("Sites", $array.get($indexG+1))  } else { $hash.add("Sites","") }
 $indexH = 0..($array.Length -1) | where { $array[$_] -eq 'networkinterfaces' }
 if($indexH) { $hash.add("NIC", $array.get($indexH+1))  } else { $hash.add("NIC","") }
 $indexI = 0..($array.Length -1) | where { $array[$_] -eq 'networksecuritygroups'}
 if($indexI) { $hash.add("NSG", $array.get($indexI+1))  } else { $hash.add("NSG","") }
 
 $indexJ = 0..($array.Length -1) | where { $array[$_] -eq 'publicipaddresses' }
 if($indexJ) { $hash.add("Public IP $indexJ", $array.get($indexJ+1)) } else { $hash.add("PublicIP","") }
 
 $indexK = 0..($array.Length -1) | where { $array[$_] -eq 'servers' } 
 if($indexK) { $hash.add("Servers",$array.get($indexK+1)) } else { $hash.add("Servers","") }
 $indexL = 0..($array.Length -1) | where { $array[$_] -eq 'databases' }
 if($indexL) { $hash.add("Databases",$array.get($indexL+1)) } else { $hash.add("Databases","") }
 $indexM = 0..($array.Length -1) | where { $array[$_] -eq 'streamingjobs' }
 if($indexM) { $hash.add("EventHubs",$array.get($indexM+1)) } else { $hash.add("EventHubs","") }
 $indexN = 0..($array.Length -1) | where { $array[$_] -eq 'storageaccounts' }
 if($indexN) { $hash.add("StorageAccounts",$array.get($indexN+1)) } else { $hash.add("StorageAccounts","") } 

 if($additionalData) { $hash.add("AdditionalData", "") } else { $hash.add("AdditionalData", "") }
 if($resourceDetails) { $hash.add("ResourceDetails", $resourceDetails) } else { $hash.add("ResourceDetails", "") }
 if($status) { $hash.add("Status", $status) } else { $hash.add("Status", "") }

 return $hash

}

$Subscriptions = Get-AzSubscription
<#
GetHashCode               Method     int GetHashCode()
GetType                   Method     type GetType()
ToString                  Method     string ToString()
AuthorizationSource       Property   string AuthorizationSource {get;}
CurrentStorageAccount     Property   string CurrentStorageAccount {get;set;}
CurrentStorageAccountName Property   string CurrentStorageAccountName {get;}
ExtendedProperties        Property   System.Collections.Generic.IDictionary[string,string] ExtendedProperties {get;}
HomeTenantId              Property   string HomeTenantId {get;set;}
Id                        Property   string Id {get;set;}
ManagedByTenantIds        Property   string[] ManagedByTenantIds {get;set;}
Name                      Property   string Name {get;set;}
State                     Property   string State {get;set;}
SubscriptionId            Property   string SubscriptionId {get;}
SubscriptionPolicies      Property   Microsoft.Azure.Commands.Profile.Models.PSAzureSubscriptionPolicy SubscriptionPoli…
Tags                      Property   System.Collections.Generic.Dictionary[string,string] Tags {get;}
TenantId                  Property   string TenantId {get;set;}
#>
foreach ($sub in $Subscriptions) {
  Get-AzSubscription -SubscriptionName $sub.Name -TenantId $sub.TenantId | Set-AzContext

  #Write-Host $sub.SubscriptionId
  AzSecurityAssessment $sub.SubscriptionId

}