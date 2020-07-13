#Ensure the automation account has the modules AzureRM.RecoveryServices and AzureRM.RecoveryServices.Backup

Param
(                    
    [Parameter(Mandatory = $true)]                
    $VMName,
    [Parameter(Mandatory = $true)]                
    $ResourceGroup,
    [Parameter(Mandatory = $true)]                
    $RecoveryVault,
    [Parameter(Mandatory = $true)]                
    $BackupPolicy
)       
$ErrorActionPreference = "Stop"

$connectionName = "AzureRunAsConnection"
try {
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
try {
    Write-Output "Getting the vault $RecoveryVault for VM $VMName in ResourceGroup $ResourceGroup"
    $vault = Get-AzureRmRecoveryServicesVault -Name $RecoveryVault
    Write-Output "Setting the context"
    $vault | Set-AzureRmRecoveryServicesVaultContext
    Write-Output "Getting the policy"    
   
    $policy = $null    
    $retryTimes = 1
    do {
        $policy = Get-AzureRmRecoveryServicesBackupProtectionPolicy -Name $BackupPolicy -ErrorAction SilentlyContinue
        if (!$policy) { Write-Output "policy could not be found" }
        sleep (Get-Random -Minimum 15 -Maximum 30)
        $retryTimes = $retryTimes + 1
    }
    while (!$policy -and ($retryTimes -le 10))
    if (!$policy) { throw "The policy could not be found" }
    write-output $policy
}
catch {
    Write-Output "Exception: $($_.Exception.Message)"
    throw  $_.Exception
}
Write-Output "Getting the container"
if (Get-AzureRmRecoveryServicesBackupContainer -ContainerType 'AzureVM' -Status 'Registered' -FriendlyName $VMName -ResourceGroupName $ResourceGroup) {
    Write-output "[SKIPPING] The VM $VMName is already registered for Backups" .
}
else {            
    try {
        Write-Output "Checking Tags"
        $VMTag = Get-AzureRMResource -ResourceGroupName $ResourceGroup -TagName Sumit -Name $VMName
        $retryTimes = 1
        If ($VMTag) {
            Write-Output "Enabling backup for $VMName"        
            
            do {   
                write-output "Enabling backup - try $retryTimes "
                Enable-AzureRmRecoveryServicesBackupProtection -Policy $policy -Name $VMName -ResourceGroupName  $ResourceGroup -ErrorAction SilentlyContinue | Out-Null  
                sleep (Get-Random -Minimum 15 -Maximum 30)
                $retryTimes = $retryTimes + 1
            }
            while (!(Get-AzureRmRecoveryServicesBackupContainer -ContainerType 'AzureVM' -Status 'Registered' -FriendlyName $VMName -ResourceGroupName $ResourceGroup) `
                    -and ($retryTimes -le 10))
            if (!(Get-AzureRmRecoveryServicesBackupContainer -ContainerType 'AzureVM' -Status 'Registered' -FriendlyName $VMName -ResourceGroupName $ResourceGroup)) {
                # Last try to catch the Azure end error for registeration failure
                Enable-AzureRmRecoveryServicesBackupProtection -Policy $policy -Name $VMName -ResourceGroupName  $ResourceGroup            
            }
        }
    }
    catch {
        Write-Output "Error occured while enabling backup for VM $VMName - Exception: $($_.Exception.Message)"
        $_.Exception
        throw  $_.Exception
    }
    if (($retryTimes -ne 1) -and ($retryTimes -le 10))
    { Write-output "Enabled the backup for VM $VMName on resource group $ResourceGroup on recovery vault $RecoveryVault" }
}           
