# OpenIn-Obsidian

[![Download script](https://img.shields.io/github/downloads/yetenol/OpenIn-Obsidian/total.svg)](https://github.com/yetenol/OpenIn-Obsidian/releases/latest/download/obsidian.exe)
[![List releases](https://img.shields.io/github/release/yetenol/OpenIn-Obsidian.svg)](https://github.com/yetenol/OpenIn-Obsidian/releases)

OpenIn-Obsidian is a command line interface to create, open, delete Obsidian vaults and to share settings, plugins and layouts between vaults.

# Usage

- **Open folder** as Obsidian vault  
	Setup vault if none exists
    ```powershell
    obsidian $path
    ```
- **Remove all trace** of Obsidian  
    Forget and cleanup file system changes
    ```powershell
    obsidian $path -RemoveVault
    ```
- **reapply** workplace layout  
    Repair the vault
    ```powershell
    obsidian $path -Force
    ```
- **right-click any folder** in Windows Explorer and click *Open as Obsidian vault*

# Features

- synchronize **settings and plugins** between all vaults and via the cloud
- import the **default workplace layout** when creating new vaults.
- **attachments** will be placed into a separate folder
- **templates** can be created in separate folder

# Build instructions

- install dependency **[ps2exe](https://github.com/MScholtes/PS2EXE)** using elevated command
	```powershell
	Install-Module ps2exe
	```

- **build an executable** from the project folder  
  by packaging the Powershell script
	```powershell
	Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
	Invoke-ps2exe -inputFile ".\obsidian.ps1" -outputFile ".\bin\obsidian.exe" -iconFile "$env:LocalAppData\Obsidian\Obsidian.exe"
	```

- **add to PATH** using elevated commands
	```powershell
	$binaryPath = ".\bin" | Convert-Path -ErrorAction Stop
	$locations = $env:PATH -split ";"
	if ($locations -contains $binaryPath) {
		return
	}
	$locations + $binaryPath -join ";" | foreach { 
		Set-ItemProperty -Path $registryKey -Name "PATH" -Value $_ 
	}    	
	```

- add **context menu entries**  
  by importing [Registry Keys](ContextMenuEntries.reg)

# Implementation

- create `.obsidian/` config folder with **symbolic links** to the global settings and plugins
- hide and git ignore config folder
- insert `.obsidian/workspace.json` once to apply default workplace layout
- create folders for templates and attachments
- open vault using [Obsidian URI protokoll](https://help.obsidian.md/Advanced+topics/Using+obsidian+URI)
