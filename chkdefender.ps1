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

function chkdefenderstat($subid,$subname) {
  $status = @{
    $true = 'Enabled'
    $false = 'Disabled'
  }
    
  # mcas = 'Microsoft Cloud App Security'
  # wdatp = 'Windows Defender Advanced Threat Protection'
  # sentinel = 'Azure SIEM'

  Get-AzDiscoveredSecuritySolution

  $pricing = Get-AzSecuritySetting | Select-Object Enabled, Id, Name, Type
  $pricing | ForEach-Object {
    Write-Host "SubscriptionID" = $subid
    Write-Host "SubscriptionName" = $subname
    Write-Host $_.Name
    Write-Host "Status" = $status[($_.Enabled -eq 'True')]

    $objpricing=[PSCustomObject]@{
        'SubscriptionID' = $subid
        'SubscriptionName' = $subname
        'Name' = $_.Name
        'Status' = $_.Enabled
    }
    $objpricing | Export-Csv chkdefender.csv -Append -NoTypeInformation -Force    

  }
}

$Subscriptions = Get-AzSubscription
foreach ($sub in $Subscriptions) {
    Get-AzSubscription -SubscriptionName $sub.Name -TenantId $sub.TenantId | Set-AzContext

    chkdefenderstat $sub.Id $sub.Name
}
