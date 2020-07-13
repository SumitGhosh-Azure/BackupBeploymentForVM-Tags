param(

   [Parameter(Mandatory = $False)]    
   [object]$VmlistJson
)


# Connect to Azure with RunAs account
$ServicePrincipalConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'

Add-AzureRmAccount `
    -ServicePrincipal `
    -TenantId $ServicePrincipalConnection.TenantId `
    -ApplicationId $ServicePrincipalConnection.ApplicationId `
    -CertificateThumbprint $ServicePrincipalConnection.CertificateThumbprint

$AzureContext = Select-AzureRmSubscription -SubscriptionId $ServicePrincipalConnection.SubscriptionID

$StorageAccountKey = Get-AutomationVariable -Name 'storageKey'

$Context = New-AzureStorageContext -StorageAccountName 'drdiag465' `
-StorageAccountKey $StorageAccountKey 
 
$vmlist= Get-AzureStorageBlobContent    -Context $Context `
-Container 'backupdata'  -Blob 'BackupDataVM.json' -Destination "C:\Program Files\" -Force

# Waiting for script download: Check for file in Program Files and increase if download fails
Start-Sleep -s 15

$vmlistJson = Get-Content -Path "C:\Program Files\BackupDataVM.json" | ConvertFrom-Json

write-output $vmlistJson

write-output "Triggering DeployBackup runbook"

## $vmlistJson = $vmlist | convertfrom-json

foreach ($vm in $vmlistJson) {        
    $params = @{"VMName" = "$($vm.VMName)"; "ResourceGroup" = "$($vm.ResourceGroup)"; "RecoveryVault" = "$($vm.RecoveryVault)"; "BackupPolicy" = "$($vm.BackupPolicy)" }
    
    Start-AzureRmAutomationRunbook `
        –AutomationAccountName 'BackupAutomation' `
        –Name 'Deploybackups' `
        -ResourceGroupName 'DR' `
        –Parameters $params | out-null    

    write-output "Launching runbook for $($vm.VMName) to onboard on vault $($vm.RecoveryVault)"
}

write-output "Finished parent runbook" 