# --------------------------------------------------------------------------------------------------------------
# 
#  Title         : Azure_VMs_Inventory_V1.0 
#  Programmed by : Mark Ayre & Marc Kean
#  Date          : December, 2017
# 
# --------------------------------------------------------------------------------------------------------------
#
#  Script to inventory the VM's (both ASM and ARM based) against all Azure subscriptions the account has access to.
#  Adapted from Azure Inventory.ps1 by Marc Kean:
#
#  Associated URL: https://marckean.com/2016/06/24/azure-inventory-powershell/
#  GitHub: https://gist.github.com/marckean/0d35d11b112f44313a440df10d1ff152#file-azure-inventory-ps1
#
#  Written with Azure PowerShell Module v5.0.1
#  https://github.com/Azure/azure-powershell/releases/tag/v5.0.1-November2017
#
# --------------------------------------------------------------------------------------------------------------

##########################################################################################
##################     Optional AAD SP Info for un-attended sign-in     ##################
##########################################################################################
# SP = Service Principal
$SP_Password = '' # or Certificate Thumbprint
$AADAppId = '1xxxa2ce-7xxb-xxx8-ad21-1f22d65f8c07'
$TenantID = 'a8c74611-6xx1-4xxx-a439-689xxx016e87' # Directory ID

# Retrieve Azure Module properties
""
"Validating installed PowerShell Version and Azure PowerShell Module version..."
$ReqVersions = Get-Module Azure -list | Select-Object Version, PowerShellVersion
# Current PowerShell version must be higher then the one required by the Azure Module
if($PSVersionTable.PSVersion.Major -lt $ReqVersions.PowerShellVersion.Major)
{
  $PSVerReq = $ReqVersions.PowerShellVersion
  $PSVerInst = $PSVersionTable.PSVersion
  "Validation failed..."
  "Installed PowerShell version: $PSVerInst"
  "Powershell version $PSVerReq required.  Please update the version of Powershell on this system"
  "Exiting Script"
  Break
} 
# Current script was tested with Azure module 5.0.1 
if($ReqVersions.Version.Major -lt 5) 
{
  $AZModuleInst = $ReqVersions.Version
  "Validation failed..."
  "Installed Azure PS Module: $AZModuleInst.  This script was tested with version 5.0.1"
  "Please download and install/update the Azure Powershell module using the Microsoft Web Platform Installer..."
  "Download link: https://github.com/Azure/azure-powershell/releases/tag/v5.0.1-November2017"
  "Exiting Script"
  Break
}

##########################################################################################
#################################     Logon to Azure    ##################################
##########################################################################################

switch -Wildcard ($SP_Password)
{
    ?* {
    
    $secpasswd = ConvertTo-SecureString $SP_Password -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential ($AADAppId, $secpasswd)
    Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId $TenantId
    }

    default {
    Login-AzureRmAccount
    }
}

##########################################################################################
###################################    Functions     #####################################
##########################################################################################

# Using logged in credentials
Function RestAPI-AuthToken ($TenantId) {

    # Load ADAL Azure AD Authentication Library Assemblies
    $adal = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
    $null = [System.Reflection.Assembly]::LoadFrom($adal)
    $null = [System.Reflection.Assembly]::LoadFrom($adalforms)

    $adTenant = $Subscription.TenantId
    # Client ID for Azure PowerShell
    $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    # Set redirect URI for Azure PowerShell
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    # Set Resource URI to Azure Service Management API | @marckean
    $resourceAppIdURIARM = "https://management.core.windows.net/"

    # Authenticate and Acquire Token

    # Set Authority to Azure AD Tenant
    $authority = "https://login.windows.net/$TenantId"
    # Create Authentication Context tied to Azure AD Tenant
    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    # Acquire token
    $global:Token = $authContext.AcquireToken($resourceAppIdURIARM, $clientId, $redirectUri, "Auto")
    }

# Using AAD Application Service Principal
Function RestAPI-SPN-AuthToken ($TenantId) {

    $Username = $Cred.Username
    $Password = $Cred.Password

    # Set Resource URI to Azure Service Management API
    $resourceAppIdURI = 'https://management.core.windows.net/'

    # Set Authority to Azure AD Tenant
    $authority = "https://login.windows.net/$TenantId"

    # Build up the credentials
    $ClientCred = [Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential]::new($UserName, $Password)
    # Acquire token
    $authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($authority)
    $global:Token = $authContext.AcquireTokenAsync($resourceAppIdURI,$ClientCred)
}

Function SPNRequestHeader {

  # Create Authorization Header
  $authHeader = $global:Token.Result.CreateAuthorizationHeader()
  # Set HTTP request headers to include Authorization header | @marckean
  $requestHeader = @{
    "x-ms-version" = "2014-10-01"; #'2014-10-01'
    "Authorization" = $authHeader
  }
  return $RequestHeader
}

Function RequestHeader {

  # Create Authorization Header
  # Set HTTP request headers to include Authorization header | @marckean
  $requestHeader = @{
    "Content-Type" = "application/json"; #'2014-10-01'
    "Authorization" = "Bearer $($global:Token.AccessToken)"
  }
  return $RequestHeader
}

##########################################################################################
#############################     Roll Through the VMs     ###############################
##########################################################################################

# Get Start Time 
$startTMD = (Get-Date)
"Starting Script: {0:HH:mm MM-dd-yyyy}..." -f $startTMD

#region Inventory of Azure VMs

$Results = @()
$ResultsDataPath = "$env:USERPROFILE\Desktop\"
$ResultsFile = "AzureVMList-{0:yyyy_MM_dd_HH-mm}" -f (Get-Date)
$ResultsFileExt = ".csv"
$ResultsCSV = "$ResultsDataPath$ResultsFile$ResultsFileExt"
$ARMsubscriptions = Get-AzureRmSubscription

" "
"Processing Azure subscriptions for the existence of VM's"

foreach($ARMsub in $ARMsubscriptions){

Select-AzureRmSubscription -SubscriptionName $ARMsub.Name

##########################################################################################
################################     Rest API Token     ##################################
##########################################################################################

switch -Wildcard ($SP_Password)
{
    ?* {
    RestAPI-SPN-AuthToken $ARMsub.TenantId # To Logon to Rest and get an an auth key
    $RequestHeader = SPNRequestHeader
    }

    default {
    RestAPI-AuthToken $ARMsub.TenantId
    $RequestHeader = RequestHeader  
    }
}


$AzureRmVMResources = Get-AzureRmResource | ? {$_.ResourceType -eq 'Microsoft.Compute/virtualMachines' -or `
                                               $_.ResourceType -eq 'Microsoft.ClassicCompute/virtualMachines' -or `
                                               $_.ResourceType -eq 'Microsoft.Compute/virtualMachines/InstanceView'}

foreach($AzureRmVMResource in $AzureRmVMResources){

$RmResource = Get-AzureRmResource -ExpandProperties -ResourceGroupName $AzureRmVMResource.ResourceGroupName `
-ResourceName $AzureRmVMResource.ResourceName -ResourceType $AzureRmVMResource.ResourceType

if($RmResource.ResourceType -eq 'Microsoft.ClassicCompute/virtualMachines'){

$w = [PSCustomObject] @{

        Subscription_Name = $ARMsub.Name
        Resource_Name = ($RmResource).ResourceName
        Deployment_Name = ($RmResource).Properties.HardwareProfile.DeploymentName
        Computer_Name = ($RmResource).Properties.InstanceView.computerName
        Fully_Qualified_Domain_Name = ($RmResource).Properties.InstanceView.FullyQualifiedDomainName
        Resource_Type = ($RmResource).ResourceType
        OS_Type = ($RmResource).Properties.StorageProfile.OperatingSystemDisk.OperatingSystem
        OS_Publisher = ($RmResource).Properties.StorageProfile.Publisher
        OS_Offer = ($RmResource).Properties.StorageProfile.OperatingSystemDisk.SourceImageName
        OS_SKU = ($RmResource).Properties.StorageProfile.ImageReference.SKU
        VM_Size = ($RmResource).Properties.HardwareProfile.Size
        Public_IP_Addresses = ($RmResource).Properties.InstanceView.PublicIpAddresses -join ' '
        Private_IP_Address = ($RmResource).Properties.InstanceView.PrivateIpAddress
        vNetName = ($RmResource).Properties.NetworkProfile.VirtualNetwork.name
        Location = ($RmResource).Location
        Provisioning_State = ($RmResource).Properties.InstanceView.Status
        Power_State = ($RmResource).Properties.InstanceView.powerState
    }
        ($RmResource).Properties
        
        $Results += $w

    }

if($RmResource.ResourceType -eq 'Microsoft.Compute/virtualMachines'){

#### API Call to get the Power State from ARM InstanceView
$VMResourceID = $($VirtualMachine.ResourceID)
$APIURL = 'https://management.azure.com'
$myAPIPath = `
"/subscriptions/$($ARMsub.id)/resourcegroups/$($AzureRmVMResource.ResourceGroupName)/providers/Microsoft.Compute/virtualMachines/$($AzureRmVMResource.name)"
$apicall = "$myAPIPath/InstanceView?api-version=2017-03-30"
$Uri = "{0}{1}" -f $APIURL, $apicall
$VMInstanceView = Invoke-RestMethod -Method Get -Headers $RequestHeader -Uri $uri

$w = [PSCustomObject] @{
        Subscription_Name = $ARMsub.Name
        Resource_Name = ($RmResource).ResourceName
        Deployment_Name = ($RmResource).Name
        Computer_Name = ($RmResource).Properties.OsProfile.ComputerName
        Fully_Qualified_Domain_Name = (Get-AzureRmPublicIpAddress | ? {$_.ID -match $RmResource.Name}).DnsSettings.Fqdn
        Resource_Type = ($RmResource).ResourceType
        OS_Type = ($RmResource).Properties.StorageProfile.OsDisk.OsType
        OS_Publisher = ($RmResource).Properties.StorageProfile.ImageReference.Publisher
        OS_Offer = ($RmResource).Properties.StorageProfile.ImageReference.Offer
        OS_SKU = ($RmResource).Properties.StorageProfile.ImageReference.SKU
        VM_Size = ($RmResource).Properties.HardwareProfile.VMSize
        Public_IP_Addresses = (Get-AzureRmPublicIpAddress | ? {$_.ID -match $RmResource.Name}).IpAddress -join ' '
        Private_IP_Address = (Get-AzureRmNetworkInterface | ? {$_.ID -match $RmResource.Name}).IpConfigurations.PrivateIpAddress
        vNetName = (Get-AzureRmVirtualNetwork | ? {$_.Subnets.ID -match  (Get-AzureRmNetworkInterface | ? {$_.ID -match $RmResource.Name}).IpConfigurations.subnet.id}).Name
        Location = ($RmResource).Location
        Provisioning_State = ($RmResource).Properties.ProvisioningState
        Power_State = ($VMInstanceView.statuses | where {$_.code -Like '*power*'}).displayStatus
    }
        $Results += $w

        }
    }
}
$Results
$Results | Export-Csv -notypeinformation -Path $ResultsCSV

#endregion

# Get End Time 
$endTMD = (Get-Date) 
"Stopping Script: {0:HH:mm MM-dd-yyyy}..." -f $endTMD 
 
# Echo Time elapsed 
"Elapsed Time: $(($endTMD-$startTMD).totalseconds) seconds" 

# Inventory output path confirmation
" "
"Inventory output to $ResultsCSV"
