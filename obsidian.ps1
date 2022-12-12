param (
    [Parameter(Mandatory)]  [String]$Path
)

# SET CONFIGURATION
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$folder = $Path | Get-Item
$cloudConfig = "D:\OneDrive\Config\Obsidian" | Get-Item
$vaultConfig = "$folder\.obsidian" | % { [System.IO.DirectoryInfo]::new($_) }
$obsidianConfig = "$env:AppData\obsidian\obsidian.json" | Get-Item
$syncContent = [string[]]@(
    '.\plugins';
    '.\app.json';
    '.\appearance.json';
    '.\community-plugins.json';
    '.\core-plugins.json';
    '.\hotkeys.json';
    '.\templates.json';
)
$obsidianURI = "obsidian://action?path=$folder"

# Open existing vaults
if (Test-Path -Path $vaultConfig) {
    Start-Process $obsidianURI
    return
}

# Make cloud files AlwaysAvailable
$syncContent | 
foreach { 
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
$commands = $syncContent | 
foreach {
    Write-Output "New-Item -ItemType SymbolicLink -Path `"$vaultConfig\$_`" -Target `"$cloudConfig\$_`" -Force"
}
$commands = $commands -join "`n"
Start-Process -Wait wt -Verb RunAs -ArgumentList "PowerShell.exe -Command $commands"

# Hide and ignore vaultConfig
$vaultConfig.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden

# Create attachments, templates folder
@('.\attachments'; '.\templates') | 
foreach { 
    New-Item -ItemType Directory -Path "$folder\$_" -ErrorAction SilentlyContinue
}

# Add folder to Obsidian vaults
$config = Get-Content -Path $obsidianConfig -Raw | ConvertFrom-Json
$unixMillis = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
$config.vaults | Add-Member -NotePropertyName $unixMillis `
    -NotePropertyValue ([PSCustomObject]@{ 
        path = $folder.FullName;
        ts   = $unixMillis;
    })
$config | ConvertTo-Json | Set-Content -Path $obsidianConfig

# Open vault
Start-Process $obsidianURI