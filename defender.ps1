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

if(-not (Get-Module Az.ResourceGraph -ListAvailable)){
Write-Host "Install Az.ResourceGraph"
Install-Module Az.ResourceGraph -Scope CurrentUser -Force
} else {
Write-Host "Az.ResourceGraph is available"
Get-Command -Module 'Az.ResourceGraph' -CommandType 'Cmdlet'
}

Write-Host ""

Get-AzLogin

Write-Host ""

# Search-AZGraph -Query "securityresources | where type == `"microsoft.security/pricings`" | extend tier = properties.pricingTier | project name, tier, subscriptionId, subscriptionName" | Sort-object tier

function defenderstat($subid,$subname) {
  $result = Get-AzSecurityPricing | Select Name, PricingTier, FreeTrialRemaingingTime
  $result | ForEach-Object {
    $objresult=[PSCustomObject]@{
        'SubscriptionID' = $subid
        'SubscriptionName' = $subname
        'Name' = $_.Name
        'PricingTier' = $_.PricingTier
    }
    $objresult | Export-Csv defender.csv -Append -NoTypeInformation -Force
  }
}

$Subscriptions = Get-AzSubscription
foreach ($sub in $Subscriptions) {
    Get-AzSubscription -SubscriptionName $sub.Name -TenantId $sub.TenantId | Set-AzContext

    defenderstat $sub.Id $sub.Name
}
