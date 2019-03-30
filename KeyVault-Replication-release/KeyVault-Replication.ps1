Trace-VstsEnteringInvocation $MyInvocation

$keyvault1 = Get-VstsInput -Name "SourceKeyVaultName"
$keyvault2 = Get-VstsInput -Name "TargetKeyVaultName"
$secretOption = Get-VstsInput -Name "secretOption"
$ReplicateDeletion = Get-VstsInput -Name "ReplicateDeletion" -AsBool
$DryRun = Get-VstsInput -Name "DryRun" -AsBool

################# Initialize Azure. #################
Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
Initialize-Azure

Write-VstsTaskVerbose "DRYRUN = $dryrun"
if ($DryRun -eq $True) {
	write-Output "Dry Run option selected.  No changes will be made to the Key Vault secrets."
}

$BackupDir = "$ENV:Temp\KV-Backup"

function update-secret ($kv1, $kv2, $secret, $removeExisting) {

    if ($DryRun -ne "true") {
        Backup-AzureKeyVaultSecret -VaultName $kv1 -Name $secret.name -OutputFile "$BackupDir\$($secret.name).secret" -Force -ErrorAction SilentlyContinue | Out-Null
        if ($removeExisting) {
            Remove-AzureKeyVaultSecret -VaultName $kv2 -Name $secret.name -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Restore-AzureKeyVaultSecret -VaultName $kv2 -InputFile "$BackupDir\$($secret.name).secret" -ErrorAction SilentlyContinue | Out-Null

        if($?) { Write-Host -ForegroundColor Green "done."}
        else { Write-Warning "##[warning]Secret operation failed"}
    }
    else {
        Write-Host -ForegroundColor Yellow "DryRun option selected.  No changes made."
    }
}

function remove-secret ($kv, $secret) {

    if ($DryRun -ne "true") {
        Remove-AzureKeyVaultSecret -VaultName $kv -Name $secret.name -Force -ErrorAction SilentlyContinue | Out-Null

        if($?) { Write-Host -ForegroundColor Green "done."}
        else { Write-Warning "##[warning]Secret operation failed"}
    }
    else {
        Write-Host -ForegroundColor Yellow "DryRun option selected.  No changes made."
    }
}

$AllSecrets1 = Get-AzureKeyVaultSecret $keyvault1
$AllSecrets2 = Get-AzureKeyVaultSecret $keyvault2

# Make temp dir
if (!(Test-Path $BackupDir)) { md $BackupDir | Out-Null }

# Get current version of all secrets
write-host -NoNewline "Downloading secret versions from $keyvault1"
foreach ($secret in $AllSecrets1) {
    $fullSecret = Get-AzureKeyVaultSecret -VaultName $keyvault1 -Name $secret.Name
    $secret.Version = $fullSecret.Version
    Write-Host -NoNewline "."
}
write-host -NoNewline "`r`nDownloading secret versions from $keyvault2"
foreach ($secret in $AllSecrets2) {
    $fullSecret = Get-AzureKeyVaultSecret -VaultName $keyvault2 -Name $secret.Name
    $secret.Version = $fullSecret.Version
    Write-Host -NoNewline "."
}

Write-Host -ForegroundColor White "`r`nReplicating from $keyvault1 -> $keyvault2"

# Copy keyvault1 secrets to keyvault2
foreach ($secret in $AllSecrets1) {

    Write-Host -NoNewline "Comparing $($secret.name) from $keyvault1... "

    # Look for matching version in target
    if ($secret.Version -in $AllSecrets2.version) {
        # TODO: Look at last updated date for 2-way replication
        Write-Host -ForegroundColor Green "##[command]matching secret found."
    }
    else {
        Write-Host "no matching secret found."

        # Secret exists and is newer than target
        If ($secret.name -in $AllSecrets2.name -and $secret.Updated -gt ($AllSecrets2 | where {$_.name -eq $secret.name}).Updated) {

            Write-Host -NoNewline "##[debug]Secret named $($secret.name) already exists in $keyvault2 and needs to be updated. "
            update-secret -kv1 $keyvault1 -kv2 $keyvault2 -secret $secret -removeExisting $TRUE

        }

        # Secret exists and is older than target
        If ($secret.name -in $AllSecrets2.name -and $secret.Updated -lt ($AllSecrets2 | where {$_.name -eq $secret.name}).Updated) {
            Write-Host -ForegroundColor Yellow "##[debug]Secret named $($secret.name) already exists in $keyvault2 and is newer in the target.  No action will be taken."
        }

        # Secret doesn't exist in the target
        If ($secret.name -notin $AllSecrets2.name) {

            Write-Host -NoNewline "##[debug]Copying $($secret.Name) to $keyvault2... "
            update-secret -kv1 $keyvault1 -kv2 $keyvault2 -secret $secret -removeExisting $FALSE

        }
    }
}

if ($secretOption -eq "OneWay" -and $ReplicateDeletion -eq $true) {

    write-Output "Deletion option selected.  Deleting any secrets from the target Key Vault that are not present in the source Key Vault."

    # Delete extra secrets in target Key Vault
    $SecretsToDelete = Compare-Object $AllSecrets1 $AllSecrets2 -Property Name -PassThru | where {$_.SideIndicator -eq "=>"}
    
    foreach ($secret in $SecretsToDelete) {

        Write-Host -NoNewline "##[debug]Deleting $($secret.Name) from $keyvault2... "
        Remove-Secret -kv $keyvault2 -secret $secret

    }
}

if ($secretOption -eq "TwoWay") {

    Write-Host -ForegroundColor White "`r`nReplicating from $keyvault2 -> $keyvault1"

    # Copy keyvault2 secrets to keyvault1
    foreach ($secret in $AllSecrets2) {

        Write-Host -NoNewline "Comparing $($secret.name) from $keyvault2... "

        # Look for matching version in target
        if ($secret.Version -in $AllSecrets1.version) {
            # TODO: Look at last updated date for 2-way replication
            Write-Host -ForegroundColor Green "##[command]matching secret found."
        }
        else {
            Write-Host "no matching secret found."

            # Secret exists and is newer than target
            If ($secret.name -in $AllSecrets1.name -and $secret.Updated -gt ($AllSecrets1 | where {$_.name -eq $secret.name}).Updated) {

                Write-Host -NoNewline "##[debug]Secret named $($secret.name) already exists in $keyvault1 and needs to be updated. "
                update-secret -kv1 $keyvault2 -kv2 $keyvault1 -secret $secret -removeExisting $TRUE

            }

            # Secret exists and is older than target
            If ($secret.name -in $AllSecrets1.name -and $secret.Updated -lt ($AllSecrets1 | where {$_.name -eq $secret.name}).Updated) {
                Write-Host -ForegroundColor Yellow "##[debug]Secret named $($secret.name) already exists in $keyvault1 and is newer in the target.  No action will be taken."
            }

            # Secret doesn't exist in the target
            If ($secret.name -notin $AllSecrets1.name) {

                Write-Host -NoNewline "##[debug]Copying $($secret.Name) to $keyvault1... "
                update-secret -kv1 $keyvault2 -kv2 $keyvault1 -secret $secret -removeExisting $FALSE

            }
        }
    }
}

# Remove temp dir
Remove-Item $BackupDir -Recurse -Force
