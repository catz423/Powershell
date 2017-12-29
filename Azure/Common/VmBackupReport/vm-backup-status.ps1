#https://docs.microsoft.com/en-us/azure/backup/backup-azure-vms-automation
#https://docs.microsoft.com/en-us/powershell/module/azurerm.recoveryservices.backup/get-azurermrecoveryservicesbackupitem?view=azurermps-4.4.0
#https://stackoverflow.com/questions/42090900/column-ordering-when-exporting-to-csv-in-powershell-controlling-the-property-e

#########################################################################################################
#Login-AzureRmAccount

function Get-BackupReport {
    $Vms = @()
    $outList = [System.Collections.ArrayList]@()
    $BackupItems = [System.Collections.ArrayList]@()

    $Subscriptions = Get-AzureRmSubscription
    $TenantId = $Subscriptions[0].TenantId
    $Subscriptions | ForEach-Object {
        $Subscription = $_

        Write-Debug ( "Subscription: {0}" -f $Subscription.Name )
        Select-AzureRmSubscription -SubscriptionName $Subscription.Name | Out-Null

        #Get ALL the backup items   
        $BackupItems = [System.Collections.ArrayList]@()    
        $Vaults = Get-AzureRmRecoveryServicesVault
        $Vaults | ForEach-Object {
            $Vault = $_
            Set-AzureRmRecoveryServicesVaultContext -Vault $Vault
            
            $Containers = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM
            Write-Debug ("Containers in {0}/{1}: {2}" -f $Subscription.Name, $Vault.Name, $Containers.Count)

            $Containers | ForEach-Object {
                $BackupItems.Add( (Get-AzureRmRecoveryServicesBackupItem -Container $_ -WorkloadType AzureVM) ) | Out-Null
            }
            Write-Debug ("BackupItems: {0}" -f $BackupItems.Count)
        }
        
        #For each VM, see if there's a backup item that references it
        $Vms = Get-AzureRmVM -Status
        Write-Debug ("`tVM count: {0}" -f $VMs.Count)
        $Vms | ForEach-Object {
            $Vm = $_
            
            Write-Debug ( "`tVM: {0}" -f $Vm.id )
            if ( $BackupItems.VirtualMachineId -icontains $Vm.Id ) {
                $FilteredBackupItems = $BackupItems | Where-Object { $_.VirtualMachineId -eq $Vm.Id }
                if ( $FilteredBackupItems.Count -gt 1 ) { Write-Warning ( "`tName collision??" ) }
                $FilteredBackupItems | ForEach-Object {
                    $BackupItem = $_
                    $out = [ordered] @{
                        "Provider" = "Azure"
                        "Subscription" = $Subscription.Name
                        "VM name" = $Vm.Name
                        "VM PowerState" = $Vm.PowerState
                        "VM Exists" = $True
                        "Status" = "Backup configured"
                        "ProtectionStatus" = $BackupItem.ProtectionStatus
                        "LastBackupStatus" = $BackupItem.LastBackupStatus
                        "LatestRecoveryPoint" = $BackupItem.LatestRecoveryPoint
                        "ProtectionPolicyName" = $BackupItem.ProtectionPolicyName
                    }
                    $outList.Add( (New-Object -TypeName PSObject -Property $out) ) | Out-Null
                }
            } else {
                $out = [ordered] @{
                    "Provider" = "Azure"
                    "Subscription" = $Subscription.Name
                    "VM name" = $Vm.Name
                    "VM PowerState" = $Vm.PowerState
                    "VM Exists" = $True
                    "Status" = "Unprotected"
                    "ProtectionStatus" = ""
                    "LastBackupStatus" = ""
                    "LatestRecoveryPoint" = ""
                    "ProtectionPolicyName" = ""
                }
                $outList.Add( (New-Object -TypeName PSObject -Property $out) ) | Out-Null
            }
        }
        
        #For each BackupItem, see if the Vm it references still exists
        $BackupItems | ForEach-Object {
            $BackupItem = $_
            
            if ( $Vms.Id -inotcontains $BackupItem.VirtualMachineId ) {
                $out = [ordered] @{
                    "Provider" = "Azure"
                    "Subscription" = $Subscription.Name
                    "VM name" = (Split-Path -Path $BackupItem.VirtualMachineId -Leaf)
                    "VM PowerState" = ""
                    "VM Exists" = $False
                    "Status" = "Orphaned"
                    "ProtectionStatus" = $BackupItem.ProtectionStatus
                    "LastBackupStatus" = $BackupItem.LastBackupStatus
                    "LatestRecoveryPoint" = $BackupItem.LatestRecoveryPoint
                    "ProtectionPolicyName" = $BackupItem.ProtectionPolicyName
                }
                $outList.Add( (New-Object -TypeName PSObject -Property $out) ) | Out-Null
            }
        }
    }

    $outList | Sort-Object -Descending -Property Status, ProtectionStatus | Out-GridView

    #$outList | Sort-Object -Descending -Property Status, ProtectionStatus | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath ("$Home\Documents\Reports\{0}-Azure-FAH-BackupReport.csv" -f (Get-Date -Format yyyyMMdd) )

    switch ($TenantId) {
        "5e564299-5ce2-4c3e-93fa-e1212bd7ceda" {
            $TenantName="FAH"
        }
        "ab9727f6-b7c5-46ad-893f-387b052795fc" {
            $TenantName="Incenter"
        }
        default {
            Write-Error "Unrecognized tenant ID"
        }
    }

    $OutFilePath=("$Home\Documents\Reports\{0}-Azure-{1}-BackupReport.xlsx" -f (Get-Date -Format yyyyMMdd), $TenantName)
    Remove-Item -Path $OutFilePath -ErrorAction SilentlyContinue

    $outList | Sort-Object -Descending -Property Status, ProtectionStatus, "VM Name" | Export-Excel `
        -Path $OutFilePath -Show -AutoSize -FreezeTopRow `
        -ConditionalText $( `
            New-ConditionalText Failed
            New-ConditionalText Unhealthy 
            New-ConditionalText UNPROTECTED
            ) -BoldTopRow
    #| Export-Excel -Path $OutFilePath -Show -AutoSize -FreezeTopRow
    
}
Get-BackupReport