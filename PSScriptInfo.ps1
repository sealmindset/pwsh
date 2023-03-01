    <#PSScriptInfo 
  
.VERSION 1.0.0 
 
.GUID 46240b62-74f7-47b4-98a6-3a492945bbf5 
  
.DESCRIPTION Azure AD Connect Sync: Use this script to get Azure VM inventoryin CSV 
  
.AUTHOR Amarnath Rajendran 
  
.Company Tech Genius 
  
.TAGS Azure VM Inventory 
  
#>
    
    
     # Sign into Azure Portal
    login-azurermaccount

    # Fetching subscription list
    $subscription_id = "xxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx"      # Enter your subscription details

   # Fetch current working directory 
    $working_directory = "c:\AzureInventory"

    new-item $working_directory -ItemType Directory -Force

$subscription_id = "bfdb51dc-468a-4717-894c-3a207dd67be2"
function Get-AzureInventory{

# Selecting the subscription
Select-AzureRmSubscription -Subscription $subscription_id

# Fetch the Virtual Machines from the subscription
$azureVMDetails = get-azurermvm

# Fetch the NIC details from the subscription
$azureNICDetails = Get-AzureRmNetworkInterface | ?{ $_.VirtualMachine -NE $null}

# Fetch the Virtual Networks from the subscription
$azureVirtualNetworkDetails = Get-AzureRmVirtualNetwork


#-----------------Fetching Virtual Machine Details-----------------#

    $virtual_machine_object = $null
    $virtual_machine_object = @()


    # Iterating over the NIC Interfaces under the subscription
        
        foreach($azureNICDetail in $azureNICDetails){ 
        $azureVMDetail = $azureVMDetails | ? -Property Id -eq $azureNICDetail.VirtualMachine.id
        $vm_status = get-azurermvm -ResourceGroupName $azureVMDetail.resourcegroupname -name $azureVMDetail.name -Status
        $vm_tags = ($azureVMDetail.Tags.values) -join ';'
        $osversion = $azureVMDetail.StorageProfile.ImageReference.id
        $vmsize = Get-AzureRmVMSize -VMName $azureVMDetail.Name -ResourceGroupName $azureVMDetail.ResourceGroupName | ? {$_.Name -eq $azureVMDetail.HardwareProfile.VmSize}
        
        #Fetching the private IP
        #write-Host $vm.NetworkInterfaceIDs
        $private_ip_address = ($azureNICDetail.IpConfigurations | select-object -ExpandProperty PrivateIpAddress) -Join ';'
        $virturalnetwork = $azureNICDetail.IpConfigurations.subnet.Id.Split("/")[-3]
        $subnet = $azureNICDetail.IpConfigurations.subnet.Id.Split("/")[-1]
            
        #Fetching data disk names
        $data_disks = $azureVMDetail.StorageProfile.DataDisks
        $data_disk_name_list = ''

            foreach ($data_disk in $data_disks) {
            $data_disk_name_list_temp = $data_disk_name_list + "; " +$data_disk.name 
            #Trimming the first three characters which contain --> " ; "
            $data_disk_name_list = $data_disk_name_list_temp.Substring(2)
            #write-host $data_disk_name_list
            }

        #} 

            # Fetching OS Details (Managed / un-managed)

            if($azureVMDetail.StorageProfile.OsDisk.manageddisk -eq $null){
                # This is un-managed disk. It has VHD property

                $os_disk_details_unmanaged = $azureVMDetail.StorageProfile.OsDisk.Vhd.Uri
                $os_disk_details_managed = "This VM has un-managed OS Disk"

            }else{
                
                $os_disk_details_managed = $azureVMDetail.StorageProfile.OsDisk.ManagedDisk.Id
                $os_disk_details_unmanaged = "This VM has Managed OS Disk"
            }

            $virtual_machine_object_temp = new-object PSObject 
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "VMName" -Value $azureVMDetail.Name
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "ResourceGroupName" -Value $azureVMDetail.ResourceGroupName
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "Location" -Value $azureVMDetail.Location
# $virtual_machine_object_temp | add-member -membertype NoteProperty -name "Zone" -Value $azureVMDetail.Zones
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "Tags" -Value $vm_tags
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "VMStatus" -Value $vm_status.Statuses[1].DisplayStatus
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "VMSize" -Value $azureVMDetail.HardwareProfile.VmSize
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "CPU" -Value $vmsize.NumberOfCores
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "RAM in MB" -Value $vmsize.MemoryInMB
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "OSFamily" -Value $azureVMDetail.StorageProfile.OsDisk.OsType
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "DiskCount" -Value $azureVMDetail.StorageProfile.DataDisks.Count
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "AdminUserName" -Value $azureVMDetail.OSProfile.AdminUsername
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "PrivateIP" -Value $private_ip_address
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "Vnet-Zone" -Value $virturalnetwork
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "Subnet" -Value $subnet
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "OSVersion" -Value $osversion
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "DataDiskNames" -Value $data_disk_name_list
            $virtual_machine_object_temp | add-member -membertype NoteProperty -name "ManagedOSDiskURI" -Value $os_disk_details_managed
                        


            $virtual_machine_object += $virtual_machine_object_temp

            
        }

        $virtual_machine_object | Export-Csv "$working_directory\Virtual_Machine_details_$(get-date -f yyyyMMdd).csv" -NoTypeInformation -Force

}

Get-AzureInventory