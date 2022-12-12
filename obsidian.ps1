param (
    [Parameter(Mandatory)]  [String]$Path,
    [Switch]$RemoveVault
)

# SET CONFIGURATION
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$Path = $Path | Convert-Path
$obsidianConfig = "$env:AppData\obsidian\obsidian.json" | Get-Item
$cloudConfig = "D:\OneDrive\Config\Obsidian" | Get-Item
$vaultConfig = "$Path\.obsidian" | foreach { [System.IO.DirectoryInfo]::new($_) }
$syncChildren = [String[]]@(
    '.\plugins\';
    '.\app.json';
    '.\appearance.json';
    '.\community-plugins.json';
    '.\core-plugins.json';
    '.\hotkeys.json';
    '.\templates.json';
)
$copyChildren = [String[]]@(
    '.\workspace.json'
)
$createFolders = [String[]]@(
    '.\attachments';
    '.\templates'
) | foreach { [System.IO.DirectoryInfo]::new("$Path/$_") }

$obsidianURI = "obsidian://action?path=$Path"
$jsonConfig = Get-Content -Path $obsidianConfig -Raw | ConvertFrom-Json
$knownVaults = $jsonConfig.vaults.PSObject.Properties | foreach {
    [PSCustomObject]@{
        ID = $_.Name;
        Path = $_.Value.Path;
    }
}

# Forget vault and remove config folder
if ($RemoveVault) {
    # Remove config folder
    if (Test-Path $vaultConfig) {
        Remove-Item -Path "$Path\.obsidian" -Recurse -Force
    }

    # Remove empty folders
    $createFolders | where Exists | where { -not (Test-Path "$_/*") } | foreach {
        Remove-Item -Path $_
    }

    # Forget vault
    $knownVaults | where Path -eq $Path | foreach {
        $jsonConfig.vaults.PSObject.Properties.Remove($_.ID)
    }
    $jsonConfig | ConvertTo-Json | Set-Content -Path $obsidianConfig
    return
}

# Open existing vaults
if (($knownVaults.Path -contains $Path) -and (Test-Path $vaultConfig)) {
    Start-Process $obsidianURI
    return
}

# Make cloud files AlwaysAvailable
$syncChildren | foreach { 
    Get-Item "$cloudConfig\$_"
} | foreach {
    if ($_.PSIsContainer) {
        # Add directory content recursively
        Get-ChildItem -Path $_ -Recurse | where { $_.PSIsContainer } | Get-Item
        Get-ChildItem -Path $_ -Recurse -File
    }
} | foreach { 
    $_.Attributes = $_.Attributes -bor 0x080000
}

# Create symlinks via elevated PowerShell
$commands = $syncChildren | foreach {
    Write-Output "New-Item -ItemType SymbolicLink -Path `"$vaultConfig\$_`" -Target `"$cloudConfig\$_`" -Force"
}
$commands = $commands -join "`n"
Start-Process -Wait wt -Verb RunAs -ArgumentList "PowerShell.exe -Command $commands"
Set-Content -Path "$vaultConfig\.gitignore" -Value "*`n!.gitignore"

# Copy workplace setup
$copyChildren | foreach {
    Copy-Item -Path "$cloudConfig\$_" -Destination "$vaultConfig\$_"
}

# Hide and ignore vaultConfig
$vaultConfig.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden

# Create folders unless already present
$createFolders | where Exists -eq $false | foreach {
    New-Item -ItemType Directory -Path $_ | Out-Null
}

# Add folder to Obsidian vaults
$jsonConfig = Get-Content -Path $obsidianConfig -Raw | ConvertFrom-Json
$alreadyPresent = $knownVaults.Path -contains $Path
if (-not $alreadyPresent) {
    [PSCustomObject]@{ 
        path = $Path;
        ts   = [DateTimeOffset]::Now.ToUnixTimeMilliseconds();
    } | foreach {
        Add-Member -MemberType NoteProperty -InputObject $jsonConfig.vaults -Name $_.ts -Value $_
    }

    $jsonConfig | ConvertTo-Json | Set-Content -Path $obsidianConfig
}

# Open vault
Start-Process $obsidianURI