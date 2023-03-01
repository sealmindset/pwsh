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

function azwebapps($subid, $subname) {
  # Get Azure WebApps across all resource groups in your Subscription
  $siteNames = Get-AzWebApp

  # Get Azure WebApp Slots across all resource groups in your Subscription
  $slotNames = $WebApp | Get-AzWebAppSlot

  # Combine the result
  $result = $siteNames + $slotNames

  $result | ForEach-Object {

    $rsid = (Get-AzResourceGroup -Name $_.ResourceGroup).ResourceId | Where-Object {$_ -ne $null}
    if($rsid) {
      Write-Debug $rsid
      $tags = Get-AzTag -ResourceId $rsid
    } 
    #$defender = Get-AzSecurityAlert
    $loganalytics = Get-AzOperationalInsightsWorkspace
    $objresult=[PSCustomObject]@{
        'SubscriptionId' = $subid
        'SubscriptionName' = $subname
        'ResourceGroup' = $_.ResourceGroup
        'ResourceId' = $rsid
        'GitRemoteName' = $_.GitRemoteName                                                                                                 
        'GitRemoteUri' = $_.GitRemoteUri                                                                                                  
        'GitRemoteUsername' = $_.GitRemoteUsername                                                                                             
        'GitRemotePassword' = $_.GitRemotePassword                                                                                             
        'AzureStorageAccounts' = $_.AzureStorageAccounts                                                                                          
        'AzureStoragePath' = $_.AzureStoragePath                                                                                              
        'State' = $_.State
        'Hostnames' = "" # $result.HostNames | Out-String # System.Collections.Generic.List`1[System.String]
        'Repository' = $_.RepositorySiteName
        'UsageState' = $_.UsageState
        'Enabled' = $_.Enabled
        'EnabledHostNames' = "" # $result.EnabledHostNames | Out-String # System.Collections.Generic.List`1[System.String]
        'AvailablityState' = $_.AvailabilityState
        'HostNameSslStates' = "" # $result.HostNameSslStates.SslState | Out-String # System.Collections.Generic.List`1[System.String]
        'ServerFarmId' = $_.ServerFarmId
        'Reserved' = $_.Reserved
        'IsXenon' = $_.IsXenon                                                                       
        'HyperV' = $_.HyperV                                                                               
        'LastModifiedTimeUtc' = $_.LastModifiedTimeUtc
        'SiteConfig' = $_.SiteConfig
        'TrafficManagerHostNames' = $_.TrafficManagerHostNames
        'ScmSiteAlsoStopped' = $_.ScmSiteAlsoStopped
        'TargetSwapSlot' = $_.TargetSwapSlot                                                                    
        'HostingEnvironmentProfile' = $_.HostingEnvironmentProfile
        'ClientAffinityEnabled' = $_.ClientAffinityEnabled
        'ClientEnabled' = $_.ClientCertEnabled
        'ClientCertMode' = $_.ClientCertMode                                                                     
        'ClientCertExclusionPaths' = $_.ClientCertExclusionPaths                                                                       
        'HostNamesDisabled' = $_.HostNamesDisabled                                                 
        'CustomDomainVerificationId' = $_.CustomDomainVerificationId         
        'OutboundIpAddresses' = $_.OutboundIpAddresses
        'PossibleOutboundIpAddresses' = $_.PossibleOutboundIpAddresses                                              
        'ContainerSize' = $_.ContainerSize                                                
        'DailyMemoryTimeQuota' = $_.DailyMemoryTimeQuota                                                                        
        'SuspendedTill' = $_.SuspendedTill                                                                  
        'MaxNumberOfWorkers' = $_.MaxNumberOfWorkers                                                                         
        'CloningInfo' = $_.CloningInfo                                                                                                                                              
        'IsDefaultContainer' = $_.IsDefaultContainer                                                                                            
        'DefaultHostName' = $_.DefaultHostName                                     
        'SlotSwapStatus' = $_.SlotSwapStatus                                                                                                
        'HttpsOnly' = $_.HttpsOnly                                                                                       
        'RedundancyMode' = $_.RedundancyMode                                                                                                
        'InProgressOperationId' = $_.InProgressOperationId                                                                                         
        'StorageAccountRequired' = $_.StorageAccountRequired                                                                                        
        'KeyVaultReferenceIdentity' = $_.KeyVaultReferenceIdentity                                                                                       
        'VirtualNetworkSubnetId' = $_.VirtualNetworkSubnetId                                                                        
        'Identity' = $_.Identity                                                                                      
        'ExtendedLocation' = $_.ExtendedLocation                                                                                       
        'Id' = $_.Id
        'Name' = $_.Name                                                    
        'Kind' = $_.Kind                                                                       
        'Location' = $_.Location                                                                         
        'Type' = $_.Type

        'Owner' = $tags.Properties.TagsProperty.Owner
        'Cost Center' = $tags.Properties.TagsProperty."Cost Center"
        'Environment' = $tags.Properties.TagsProperty.Environment

        

        }

        $objresult | Export-Csv data.csv -Append -NoTypeInformation -Force

    }
}

function getalerts($name) {
  Write-Host $name
  $defenders = Get-AzSecurityAlert -Name $name

  Write-Host $defenders

}

$Subscriptions = Get-AzSubscription
foreach ($sub in $Subscriptions) {
    Get-AzSubscription -SubscriptionName $sub.Name -TenantId $sub.TenantId | Set-AzContext

    #Write-Host ""
    #Write-Host ""
    #$resultsSub = $sub.Id + " - " + $sub.Name
    #$resultssub | Out-File -FilePath data.csv -Append -force

    azwebapps $sub.Id $sub.Name
}
