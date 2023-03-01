<#
    .SYNOPSIS
        Single Pane of Glass
    .DESCRIPTION
        Leverage all of the information available in Azure to identify vulnerabilities by assets
    .NOTES
        Must have READ Access to the entire Tenant

   
    .EXAMPLE
        Get-AzureVmInfo.ps1 -FileName AzureVmAudit -Path C:\Audit
#>

Param(
    [Parameter(Mandatory = $true,
              HelpMessage = "File name of the audit report",
              Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]
    $FileName,

    [Parameter(Mandatory = $true,
              HelpMessage = "Location where the audit report is stored",
              Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Path
)

$subscriptions = Get-AzSubscription
$date = Get-Date -UFormat "%Y_%m_%d_%H%M%S"

class VmCsv {
    [Object]${SubscriptionId}
    [Object]${SubscriptionName}
    [Object]${VmName}
    [Object]${ResourceGroupName}
    [Object]${Location}
    [Object]${PrivateIp}
    [Object]${HostName}
    [Object]${Os}
    [Object]${OsDetail}
    [Object]${CreatedBy}
    [Object]${ResourceClass}
    [Object]${vmSoftware}
}

$vmCsvReport = @()

foreach ($subscription in $subscriptions) {
    Set-AzContext -SubscriptionId $subscription.id
    Write-Host -ForegroundColor Green "[!] Start checking subscription:" $subscription.Name
    $vms = Get-AzVm -Status
    $nics = Get-AzNetworkInterface | Where-Object {$null -ne $_.VirtualMachine}
    $vmRD = @()
    foreach ($nic in $nics) {
        $vmObj = [vmCsv]::new()
        $vm = $vms | Where-Object { $_.id -eq $nic.VirtualMachine.id }
        Write-Host $nic.VirtualMachine.Id
        Write-Host "Admin Username: " $vm.OSProfile.AdminUsername
        $vmObj.SubscriptionId = $subscription.Id
        $vmObj.SubscriptionName = $subscription.Name
        $vmObj.VmName = $vm.Name
        Write-Host -ForegroundColor Yellow "`t Found a Virtual Machine named:" $vm.Name
        $vmObj.ResourceGroupName = $vm.ResourceGroupName
        $vmObj.Location = $vm.Location
        $vmObj.PrivateIp = $nic.IpConfigurations.PrivateIpAddress
        $vmObj.HostName = $vm.OSProfile.ComputerName
        
        if($($vm.OSProfile.LinuxConfiguration)) {
            $vmObj.Os = "Linux"
        }
        elseif ($($vm.OSProfile.WindowsConfiguration)) {
            $vmObj.Os = "Windows"
        }
        $vmObj.OsDetail = $vm.StorageProfile.ImageReference.Offer + $vm.StorageProfile.ImageReference.Sku

        $vmObj.CreatedBy = $vm.Tags.Creator
        $vmObj.ResourceClass = $vm.Tags.ResourceClass

        $resourceDetails = Search-AzGraph -query "securityresources | where type == 'microsoft.security/softwareinventories' and " # | project id, Vendor=properties.vendor, Software=properties.softwareName, Version=properties.version"

        Write-Host `"$($vm.Name)`"
        #$vmObj.vmSoftware = $resourceDetails.Name | Out-String
        Write-Host $resourceDetails.Name
        $vmCsvReport += $vmObj
    }
}

$vmCsvReport | Export-Csv -Path "$Path\$($FileName)_$($date).csv" -NoTypeInformation -Encoding UTF8
