param (
    [Parameter(Mandatory)]  [String]$Path,
    [Switch]$Force,
    [Switch]$RemoveVault
)

# SET CONFIGURATION
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
[String] $Path = $Path | Convert-Path | % { $_ -replace "\\$", "" }
[IO.FileInfo] $obsidianConfig = "$env:AppData\obsidian\obsidian.json" | Get-Item
[IO.DirectoryInfo] $cloudConfig = "D:\OneDrive\Config\Obsidian" | Get-Item
[IO.DirectoryInfo] $vaultConfig = "$Path\.obsidian" | foreach { [IO.DirectoryInfo]::new($_) }
[String[]] $syncChildren = @(
    '.\plugins\';
    '.\app.json';
    '.\appearance.json';
    '.\community-plugins.json';
    '.\core-plugins.json';
    '.\hotkeys.json';
    '.\templates.json';
)
[String[]] $copyChildren = @(
    '.\workspace.json';
    '.\graph.json'
)
[IO.DirectoryInfo[]] $createFolders = @(
    '.\attachments';
    '.\templates'
) | foreach { [IO.DirectoryInfo]::new("$Path/$_") }

[String] $obsidianURI = "obsidian://action?path=$Path"
[PSCustomObject] $jsonConfig = Get-Content -Path $obsidianConfig -Raw | ConvertFrom-Json
[PSCustomObject[]] $knownVaults = $jsonConfig.vaults.PSObject.Properties | foreach {
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
$isOpeningAllowed = $Force -eq $false
$doesVaultExists = $knownVaults.Path -contains $Path
$isVaultInitialized = Test-Path -Path $vaultConfig
if ($isOpeningAllowed -and $doesVaultExists -and $isVaultInitialized) {
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
Start-Process wt.exe "PowerShell.exe -Command $commands" -Wait -Verb RunAs -WindowStyle Hidden
# Hide and ignore vaultConfig
Set-Content -Path "$vaultConfig\.gitignore" -Value "*`n!.gitignore"
$vaultConfig.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden

# Import workplace setup
$copyChildren | foreach {
    Copy-Item -Path "$cloudConfig\$_" -Destination "$vaultConfig\$_"
}

# Create folders if none exist
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