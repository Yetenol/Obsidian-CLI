# & cls & powershell -Command Start-Process wt -Verb RunAs -ArgumentList """PowerShell.exe -Command cd "%CD%" `n Invoke-Command -ScriptBlock ([ScriptBlock]::Create(((Get-Content %0) -join [Environment]::NewLine)))""" & exit
# Script is executable and self-elevating when renamed *.cmd or *.bat

# SET CONFIGURATION
$cloudPath = "D:\OneDrive\Config\Obsidian"
$localPath = ".obsidian"

# Validate paths
if (-not (Test-Path $cloudPath)) {
    throw "Cannot find cloud location $cloudPath"
}
if (-not (Test-Path $localPath)) {
    throw "Folder has never been opened in Obsidian $localPath"
}

# Confirm folder
$path = (Resolve-Path .).Path
Write-Host "Opening " -NoNewline
Write-Host $path -ForegroundColor Cyan -NoNewline
Write-Host " in Obsidian" -NoNewline
1..5 |
foreach { 
    Start-Sleep -Seconds 1
    Write-Host "." -NoNewline
}

# Make cloud files AlwaysAvailable
$cloudPath | 
foreach {
    $item = Get-Item -Path $_    
    Write-Output $item
    if ($item.PSIsContainer) {
        # Add directory content recursively
        Get-ChildItem -Path $item -Recurse | where { $_.PSIsContainer } | Get-Item
        Get-ChildItem -Path $item -Recurse -File
    }
} | 
foreach { 
    $_.Attributes = $_.Attributes -bor 0x080000
}

# Create symlinks
try {
    Remove-Item -Path $localPath -Recurse
}
catch {
}
New-Item -ItemType SymbolicLink -Name $localPath -Target $cloudPath -Force

# Attribute symblink as SYSTEM
$item = Get-Item -Path $localPath
# $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::System -bor [System.IO.FileAttributes]::Hidden
$path = (Resolve-Path .).Path
Start-Process "obsidian://action?path=$path"

while ($Error) {}   # Keep alive on failure