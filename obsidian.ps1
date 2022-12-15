param (
    [Parameter(Mandatory)] [String] $Path,
    [Switch] $Force,
    [Switch] $RemoveVault,
    [String] $GlobalConfig = "D:\OneDrive\Config\Obsidian",
    [String] $ObsidianConfig = "$env:AppData\obsidian\obsidian.json",
    [String] $VaultConfig = ".\.obsidian",
    [String[]] $SyncContent = @(
        '.\plugins\';
        '.\app.json';
        '.\appearance.json';
        '.\community-plugins.json';
        '.\core-plugins.json';
        '.\hotkeys.json';
        '.\templates.json';
    ),
    [String[]] $CopyContent = @(
        '.\workspace.json';
        '.\graph.json';
    ),
    [String[]] $CreateFolders = @(
        '.\attachments';
        '.\templates';
    )
)

# Input validation, formatting
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
[String] $Path = $Path -replace '[\\/]$', '' | Convert-Path
[IO.FileInfo] $ObsidianConfig = $ObsidianConfig | Get-Item
[IO.DirectoryInfo] $GlobalConfig = $GlobalConfig -replace '[\\/]$', '' | Get-Item

Set-Location -Path $Path
[IO.DirectoryInfo] $VaultConfig = $VaultConfig -replace '[\\/]$', '' | foreach {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_)
} | foreach { 
    [IO.DirectoryInfo]::new($_)
}

$SyncContent + $CopyContent + $CreateFolders | where { 
    [IO.Path]::IsPathRooted($_)
} | foreach {
    Write-Error "Content must be a relative path: $_"
}
[String[]] $SyncContent = $SyncContent | where { Get-Item "$globalConfig\$_" -Force }
[String[]] $CopyContent = $CopyContent | where { Get-Item "$globalConfig\$_" -Force }
[IO.DirectoryInfo[]] $CreateFolders = $CreateFolders | foreach { 
    [IO.DirectoryInfo]::new("$Path/$_")
}

[String] $obsidianURI = "obsidian://action?path=$Path"
[PSCustomObject] $jsonConfig = Get-Content -Path $ObsidianConfig -Raw | ConvertFrom-Json
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
    $CreateFolders | where Exists | where { -not (Test-Path "$_/*") } | foreach {
        Remove-Item -Path $_
    }

    # Forget vault
    $knownVaults | where Path -eq $Path | foreach {
        $jsonConfig.vaults.PSObject.Properties.Remove($_.ID)
    }
    $jsonConfig | ConvertTo-Json | Set-Content -Path $ObsidianConfig
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
$SyncContent | foreach { 
    Get-Item "$GlobalConfig\$_"
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
$commands = $SyncContent | foreach {
    Write-Output "New-Item -ItemType SymbolicLink -Path `"$vaultConfig\$_`" -Target `"$GlobalConfig\$_`" -Force"
}
$commands = $commands -join "`n"
Start-Process wt.exe "PowerShell.exe -Command $commands" -Wait -Verb RunAs -WindowStyle Hidden
# Hide and ignore vaultConfig
Set-Content -Path "$vaultConfig\.gitignore" -Value "*`n!.gitignore"
$vaultConfig.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden

# Import workplace setup
$CopyContent | foreach {
    Copy-Item -Path "$GlobalConfig\$_" -Destination "$vaultConfig\$_"
}

# Create folders if none exist
$CreateFolders | where Exists -eq $false | foreach {
    New-Item -ItemType Directory -Path $_ | Out-Null
}

# Add folder to Obsidian vaults
$jsonConfig = Get-Content -Path $ObsidianConfig -Raw | ConvertFrom-Json
$alreadyPresent = $knownVaults.Path -contains $Path
if (-not $alreadyPresent) {
    [PSCustomObject]@{ 
        path = $Path;
        ts   = [DateTimeOffset]::Now.ToUnixTimeMilliseconds();
    } | foreach {
        Add-Member -MemberType NoteProperty -InputObject $jsonConfig.vaults -Name $_.ts -Value $_
    }

    $jsonConfig | ConvertTo-Json | Set-Content -Path $ObsidianConfig
}

# Open vault
Start-Process $obsidianURI