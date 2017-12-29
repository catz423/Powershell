##Written by Plexxi to Demo the integration with Plexxi

## Assign variables

$NtnxClusterIP = "172.24.33.102"
$NtnxUserName  = "admin"

$vlanIdList = ( 20, 40, 50 )

$NetworkBaseName = "mm-vlan"

$vmBaseName    = "MM-VM-VLAN"
$vCpuCount     = 2
$MemoryMB      = 2048
$DiskSizeMB    = 51200
$ContainerName = "default-container-74836"

# Set error handling

$ErrorActionPreference = "Stop"

# Load the Nutanix snap-in

Add-PSSnapin -Name NutanixCmdletsPSSnapin

# Connect to the Nutanix cluster

$NtnxPassword = Read-Host -AsSecureString -Prompt "Enter the password for `"$( $NtnxUserName )`""

Connect-NutanixCluster -Server $NtnxClusterIP -UserName $NtnxUserName -Password $NtnxPassword  -AcceptInvalidSSLCerts 

# Get the container to use for the VM disks

$Container = Get-NTNXContainer | Where-Object { $_.Name -eq $ContainerName }

# Loop through each VLAN ID, create the VLAN and a new VM that uses the VLAN

ForEach ( $vlanId IN $vlanIdList )
{
    ## Create the network for the VLAN Id

    $NetworkName = $NetworkBaseName + $vlanId.ToString()

    Write-Host "Creating the network `"$NetworkName`" on VLAN $( $vlanId.ToString() )" -ForegroundColor Green

    $Task = New-NTNXNetwork -Name $NetworkName -VlanId $vlanId

    # Wait for the task to finish

    While ( Get-NTNXTask -IncludeCompleted | Where-Object { $_.parentTaskUuid -eq $Task.taskUuid -and $_.percentageComplete -lt 100 }  )
    {
        Start-Sleep -Seconds 1
    }

    # Get the network

    $Network = Get-NTNXNetwork | Where-Object { $_.Name -eq $NetworkName }

    ## Create the VM

    $vmName = $vmBaseName + $vlanId.ToString()

    Write-Host "Creating the VM `"$vmName`"" -ForegroundColor Green

    $Task = New-NTNXVirtualMachine -Name $vmName -NumVcpus $vCpuCount -MemoryMB $MemoryMB

    # Wait for the task to finish

    While ( Get-NTNXTask -IncludeCompleted | Where-Object { $_.parentTaskUuid -eq $Task.taskUuid -and $_.percentageComplete -lt 100 }  )
    {
        Start-Sleep -Seconds 1
    }

    # Get the vmId of the VM

    $vmInfo = Get-NTNXVM | Where-Object { $_.vmName -eq $vmName }
    $vmId   = ( $vmInfo.vmId.Split(":") )[2]

    ## Add a NIC to the VM

    Write-Host "Adding a NIC on network `"$( $Network.Name )`" to the VM" -ForegroundColor Green

    $vmNic = New-NTNXObject -Name VMNicSpecDTO
    $vmNic.networkUuid = $Network.uuid

    $Task = Add-NTNXVMNic -Vmid $vmId -SpecList $vmNic

    # Wait for the task to finish

    While ( Get-NTNXTask -IncludeCompleted | Where-Object { $_.parentTaskUuid -eq $Task.taskUuid -and $_.percentageComplete -lt 100 }  )
    {
        Start-Sleep -Seconds 1
    }

    ## Add a disk to the VM

    Write-Host "Adding a disk to the VM" -ForegroundColor Green

    # Create the disk spec

    $DiskSpec = New-NTNXObject -Name VmDiskSpecCreateDTO
    $DiskSpec.containerUuid = $Container.containerUuid
    $DiskSpec.sizeMb        = $DiskSizeMB

    # Create the disk

    $vmDisk = New-NTNXObject –Name VMDiskDTO
    $vmDisk.vmDiskCreate = $DiskSpec

    # Add the disk to the VM

    $Task = Add-NTNXVMDisk -Vmid $vmId -Disks $vmDisk

    # Wait for the task to finish

    While ( Get-NTNXTask -IncludeCompleted | Where-Object { $_.parentTaskUuid -eq $Task.taskUuid -and $_.percentageComplete -lt 100 }  )
    {
        Start-Sleep -Seconds 1
    }

    Write-Host "Power on VM `"$vmName`"" -ForegroundColor Green
    
    $Task = Set-NTNXVMPowerOn -Vmid $vmId
    While ( Get-NTNXTask -IncludeCompleted | Where-Object { $_.parentTaskUuid -eq $Task.taskUuid -and $_.percentageComplete -lt 100 } )
    {
        Start-Sleep -Seconds 1
    }
}
