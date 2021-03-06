<#
.SYNOPSIS 
	Automates the process of creating .zip backup files of user specified folders.
	
.DESCRIPTION 
	This script uses the 7-zip archive utility to create .zip archive files of user specified folders. This script can be ran via the command line using parameters, or it can be ran without parameters to use its GUI.
	
.PARAMETER InputPath 
	Specify the folder that is to be backed up.
.PARAMETER OutputPath 
	Specify the folder to which the backup will be saved.
.PARAMETER OutputFormat
	Specify the archive file format to compress the backup to. Supported formats are .tar, tar.gz, tar.lz and tar.xz. The default is .tar.gz
.PARAMETER BackupList
	Backup folders listed in the backuplist.txt file.
.PARAMETER Install
	Install the script to "C:\Users\%USERNAME%\Scripts\PowerShell-Backup" and create desktop and Start Menu shortcuts.
.PARAMETER UpdateScript
	Update the backup.ps1 script file to the most recent version.
.PARAMETER NoTarUpdate
	Default behaviour is to only append files newer than copy in archive. Use this to flag to create another copy of the archive (not recommended as it will copy *everything* again).

.EXAMPLE
	C:\Users\%USERNAME%\Scripts\Backup-Script\scripts\backup.ps1
	Runs the script in GUI mode.
.EXAMPLE
	C:\Users\%USERNAME%\Scripts\Backup-Script\scripts\backup.ps1 -InputPath "C:\Users\mpb10\Documents" -OutputPath "E:\Backups" -OutputFormat ".7z"
	Backups the Documents folder to "E:\Backups" compressed to the .7z format.
.EXAMPLE
	C:\Users\%USERNAME%\Scripts\Backup-Script\scripts\backup.ps1 -BackupList
	Backs up the folders listed in "C:\Users\%USERNAME%\Scripts\PowerShell-Backup\config\BackupList.txt"
.EXAMPLE
	C:\Users\%USERNAME%\Scripts\Backup-Script\scripts\backup.ps1 -BackupList -InputPath "C:\TestFolder\BackupList.txt"
	Backs up the folders listed in "C:\TestFolder\BackupList.txt".
.EXAMPLE
	C:\Users\%USERNAME%\Scripts\Backup-Script\scripts\backup.ps1 -Install
	Installs the script to "C:\Users\%USERNAME%\Scripts\PowerShell-Backup" and creates desktop and Start Menu shortcuts.
.EXAMPLE
	C:\Users\%USERNAME%\Scripts\Backup-Script\scripts\backup.ps1 -UpdateScript
	Updates the backup.ps1 script file to the most recent version.

.NOTES
    Requires PowerShell version 5.0 or greater.
	Authors: mpb10
	Maintainers: rbbits
	Updated: October 2020
	Version: 2.1.1
	Read more at: https://www.commandlinux.com/man-page/man1/tar.1.html
.LINK 
	https://github.com/petmedix/PowerShell-Backup
#>

# ======================================================================================================= #
# ======================================================================================================= #

Param (
	[String]$InputPath,
	[String]$OutputPath,
	[String]$OutputFormat,
	[Switch]$BackupList,
	[Switch]$Install,
	[Switch]$UpdateScript,
	[Switch]$NoTarUpdate = $False
)


# ======================================================================================================= #
# ======================================================================================================= #
#
# SCRIPT SETTINGS
#
# ======================================================================================================= #

$CheckForUpdates = $True
$OutputFormat = ".tar.gz"

# ======================================================================================================= #
# ======================================================================================================= #
#
# LIBRARY
# 
# # The code repository for this project is Public
#
# ======================================================================================================= #

$rcloneDownloadUri = "https://downloads.rclone.org/v1.53.2/rclone-v1.53.2-windows-amd64.zip"
$codeRepository = "https://raw.githubusercontent.com/petmedix/PowerShell-Backup/master"
$InstallLocation = $ENV:USERPROFILE + "\Scripts\PowerShell-Backup"
$DesktopFolder = $ENV:USERPROFILE + "\Desktop"
$StartFolder = $ENV:APPDATA + "\Microsoft\Windows\Start Menu\Programs\PowerShell-Backup"
[Version]$RunningVersion = '2.1.1'
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
$CurrentDate = Get-Date -UFormat "%m-%d-%Y"
$BackupFolderStatus = $True
$BackupFromFileStatus = $True



# ======================================================================================================= #
# ======================================================================================================= #
#
# FUNCTIONS
#
# ======================================================================================================= #

# Function for simulating the 'pause' command of the Windows command line.
Function PauseScript {
	If ($CommandLine -eq $False) {
		Write-Host "`nPress any key to continue ...`n" -ForegroundColor "Gray"
		$Wait = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
	}
}



Function DownloadFile {
	Param(
		[String]$URLToDownload,
		[String]$SaveLocation
	)
	Invoke-WebRequest -Uri "$URLToDownload" -OutFile "$TempFolder\download.tmp"
	Move-Item -Path "$TempFolder\download.tmp" -Destination "$SaveLocation" -Force
}

Function DownloadRclone {
	DownloadFile $rcloneDownloadUri "$BinFolder\rclone.zip"
	Push-Location $BinFolder
	Expand-Archive -Path "rclone.zip" -DestinationPath ".\"
	Move-Item -Path "rclone-*" -Destination "rclone"
	Remove-Item -Path "rclone.zip"
	Pop-Location
}

Function ScriptInitialization {
	$Script:BinFolder = $RootFolder + "\bin"
	If ((Test-Path "$BinFolder") -eq $False) {
		New-Item -Type Directory -Path "$BinFolder" | Out-Null
	}
	$ENV:Path += ";$BinFolder"

	$Script:TempFolder = $RootFolder + "\temp"
	If ((Test-Path "$TempFolder") -eq $False) {
		New-Item -Type Directory -Path "$TempFolder" | Out-Null
	}
	Else {
		Remove-Item -Path "$TempFolder\download.tmp" -ErrorAction Silent
	}

	$Script:ConfigFolder = $RootFolder + "\config"
	If ((Test-Path "$ConfigFolder") -eq $False) {
		New-Item -Type Directory -Path "$ConfigFolder" | Out-Null
	}

	$Script:BackupListFile = $ConfigFolder + "\BackupList.txt"
	If ((Test-Path "$BackupListFile") -eq $False) {
		DownloadFile "${codeRepository}/install/files/BackupList.txt" "$ConfigFolder\BackupList.txt"
	}
}



Function InstallScript {
	If ($PSScriptRoot -eq "$InstallLocation") {
		Write-Host "`nPowerShell-Backup files are already installed."
	}
	Else {
		$MenuOption = Read-Host "`nInstall PowerShell-Backup to ""$InstallLocation""? [y/n]"
		
		If ($MenuOption.Trim() -like "y" -or $MenuOption.Trim() -like "yes") {
			Write-Host "`nInstalling to ""$InstallLocation"" ..."

			$Script:RootFolder = $InstallLocation
			ScriptInitialization
			
			If ((Test-Path "$StartFolder") -eq $False) {
				New-Item -Type Directory -Path "$StartFolder" | Out-Null
			}

			Copy-Item "$PSScriptRoot\backup.ps1" -Destination "$RootFolder"
			
			DownloadFile "${codeRepository}/install/files/PowerShell-Backup.lnk" "$RootFolder\PowerShell-Backup.lnk"
			Copy-Item "$RootFolder\PowerShell-Backup.lnk" -Destination "$DesktopFolder\PowerShell-Backup.lnk"
			Copy-Item "$RootFolder\PowerShell-Backup.lnk" -Destination "$StartFolder\PowerShell-Backup.lnk"
			DownloadFile "${codeRepository}/LICENSE" "$RootFolder\LICENSE.txt"
			DownloadFile "${codeRepository}/README.md" "$RootFolder\README.md"

			Write-Host "`nInstallation complete. Please restart the script." -ForegroundColor "Yellow"
			PauseScript
			Exit
		}
	}
}



Function UpdateScript {
	DownloadFile "${codeRepository}/install/files/version-file" "$TempFolder\version-file.txt"
	[Version]$NewestVersion = Get-Content "$TempFolder\version-file.txt" | Select -Index 0
	#Remove-Item -Path "$TempFolder\version-file.txt"
	
	If ($NewestVersion -gt $RunningVersion) {
		Write-Host "`nA new version of PowerShell-Backup is available: v$NewestVersion" -ForegroundColor "Yellow"
		$MenuOption = Read-Host "`nUpdate to this version? [y/n]"
		
		If ($MenuOption.Trim() -like "y" -or $MenuOption.Trim() -like "yes") {
			DownloadFile "${codeRepository}/backup.ps1" "$RootFolder\backup.ps1"
			
			If ($PSScriptRoot -eq "$InstallLocation") {
				If ((Test-Path "$StartFolder") -eq $False) {
					New-Item -Type Directory -Path "$StartFolder" | Out-Null
				}
				
				Copy-Item "$RootFolder\PowerShell-Backup.lnk" -Destination "$DesktopFolder\PowerShell-Backup.lnk"
				Copy-Item "$RootFolder\PowerShell-Backup.lnk" -Destination "$StartFolder\PowerShell-Backup.lnk"
				DownloadFile "${codeRepository}/LICENSE" "$RootFolder\LICENSE.txt"
				DownloadFile "${codeRepository}/README.md" "$RootFolder\README.md"
			}
			
			DownloadFile "${codeRepository}/install/files/UpdateNotes.txt" "$TempFolder\UpdateNotes.txt"
			Get-Content "$TempFolder\UpdateNotes.txt"
			Remove-Item "$TempFolder\UpdateNotes.txt"
			
			Write-Host "`nUpdate complete. Please restart the script." -ForegroundColor "Yellow"
			PauseScript
			Exit
		}
	}
	ElseIf ($NewestVersion -eq $RunningVersion) {
		Write-Host "`nThe running version of PowerShell-Backup is up-to-date." -ForegroundColor "Yellow"
	}
	Else {
		Write-Host "`n[ERROR] Script version mismatch. Re-installing the script is recommended." -ForegroundColor "Red" -BackgroundColor "Black"
	}
}



Function BackupFolder {
	Param (
		[Parameter(Mandatory)]
		[String]$InputFolder,
		[Parameter(Mandatory)]
		[String]$OutputFolder,
		[Switch]$NoTarUpdate
	)
	$Script:BackupFolderStatus = $True
	
	If ((Test-Path "$InputFolder" -PathType Container) -eq $False) {
		Write-Host "`n[ERROR] Provided input path does not exist or is not a folder." -ForegroundColor "Red" -BackgroundColor "Black"
		$Script:BackupFolderStatus = $False
		Return
	}
	
	If ((Test-Path "$OutputFolder" -PathType Container) -eq $False) {
		Write-Host "`n[WARNING] The provided output folder of ""$OutputFolder"" does not exist."
		$MenuOption = Read-Host "          Create this folder? [y/n]"
		
		If ($MenuOption.Trim() -like "y" -or $MenuOption.Trim() -like "yes") {
			New-Item -Type Directory -Path "$OutputFolder" | Out-Null
		}
		Else {
			Write-Host "`n[ERROR] No valid output folder was provided." -ForegroundColor "Red" -BackgroundColor "Black"
			$Script:BackupFolderStatus = $False
			Return
		}
	}
	
	$InputFolderBottom = $InputFolder.Replace(" ", "_") | Split-Path -Leaf

	$tarOptions = "-cv"
	$tarOptionsLzma = ""

    If (($OutputFormat.Trim()) -like "*tar.gz") {
		$FileFormat = ".tar.gz"
		$tarOptions += "z"
	}
	ElseIf (($OutputFormat.Trim()) -like "*tar.bz2") {
		$FileFormat = ".tar.bz2"
		$tarOptions += "j"
	}
	ElseIf (($OutputFormat.Trim()) -like "*tar.xz") {
		$FileFormat = ".tar.xz"
		$tarOptions += "J"
	}
	ElseIf (($OutputFormat.Trim()) -like "*tar.lz") {
		$FileFormat = ".tar.lz"
		$tarOptionsLzma += " --lzma"
	}
	ElseIf (($OutputFormat.Trim()) -like "*tar") {
		$FileFormat = ".tar"
	}
	
	$OutputFileName = "$OutputFolder\$InputFolderBottom" + "_" + "$CurrentDate$FileFormat"
	
	if ($NoTarUpdate) {
		$Counter = 0
		While ((Test-Path "$OutputFileName") -eq $True) {
			$Counter++
			$OutputFileName = "$OutputFolder\$InputFolderBottom" + "_" + "$CurrentDate ($Counter)$FileFormat"
		}
	} else {
		$tarOptions += "u"
	}
	
	Write-Host "`nCompressing folder: ""$InputFolder""`nCompressing to:     ""$OutputFileName""" -ForegroundColor "Green"
	
	$tarOptions += "f"
	$tarCommand = "tar.exe" + $tarOptions + " " + $OutputFileName + " " + $InputFolder + " " + $tarOptionsLzma + " " + "\*"
	Write-Verbose "tar command: $tarCommand"
	
	If ($VerboseTar -eq $True) {
		Invoke-Expression "$tarCommand" | Tee-Object "$TempFolder\powershell-backup_log.log" -Append
	}
	Else {
		Invoke-Expression "$tarCommand" | Out-File "$TempFolder\powershell-backup_log.log" -Append
	}
	
	Write-Host "`nCompression to ""$OutputFileName"" complete." -ForegroundColor "Yellow"
}



Function BackupFromFile {
	Param (
		[Parameter(Mandatory)]
		[String]$InputFile,
		[Switch]$NoTarUpdate
	)
	$Script:BackupFromFileStatus = $True
	
	If ((Test-Path "$InputFile") -eq $False) {
		Write-Host "`n[ERROR] Provided input file does not exist." -ForegroundColor "Red" -BackgroundColor "Black"
		$Script:BackupFromFileStatus = $False
		Return
	}
	
	$BackupListArray = Get-Content "$InputFile" | Where-Object {$_.Trim() -ne "" -and $_.Trim() -notlike "#*"}
	
	$BackupFromArray = $BackupListArray | Select-Object -Index (($BackupListArray.IndexOf("[Backup From]".Trim()))..($BackupListArray.IndexOf("[Backup To]".Trim())-1))
	$BackupToArray = $BackupListArray | Select-Object -Index (($BackupListArray.IndexOf("[Backup To]".Trim()))..($BackupListArray.Count - 1))
	
	If ($BackupToArray.Count -eq 1) {
		Write-Host "`n[ERROR] No output folder paths listed under '[Backup To]'." -ForegroundColor "Red" -BackgroundColor "Black"
		$Script:BackupFromFileStatus = $False
		Return
	}
	ElseIf ($BackupToArray.Count -gt 1) {
		$BackupToArray = @($BackupToArray | Where-Object {$_ -ne $BackupToArray[0]})
	}
	
	If ($BackupFromArray.Count -gt 1) {
		Write-Host "`nStarting batch job from file: ""$InputFile""" -ForegroundColor "Green"
		
		$BackupFromArray | Where-Object {$_ -ne $BackupFromArray[0]} | ForEach-Object {
			$Counter = 0
			While ($BackupToArray.Count -gt $Counter) {
				BackupFolder "$_" $BackupToArray[$Counter], $NoTarUpdate
				$Counter++
			}
		}
	}
	Else {
		Write-Host "`n[ERROR] No input folder paths listed under '[Backup From]'." -ForegroundColor "Red" -BackgroundColor "Black"
		$Script:BackupFromFileStatus = $False
		Return
	}
	
	Write-Host "`nBatch job complete." -ForegroundColor "Yellow"
}



Function CommandLineMode {
	If ($Install -eq $True) {
		InstallScript
		Exit
	}
	ElseIf ($UpdateScript -eq $True) {
		UpdateScript
		Exit
	}

	If ($BackupList -eq $True -and ($OutputPath.Length) -gt 0) {
		Write-Host "`n[ERROR]: The parameter -BackupList can't be used with -OutputPath.`n" -ForegroundColor "Red" -BackgroundColor "Black"
	}
	ElseIf ($BackupList -eq $True -and ($InputPath.Length) -gt 0) {
		BackupFromFile "$InputPath" $NoTarUpdate
		If ($BackupFromFileStatus -eq $True) {
			Write-Host "`nBackups complete.`n" -ForegroundColor "Yellow"
		}
	}
	ElseIf ($BackupList -eq $True) {
		BackupFromFile "$BackupListFile" $NoTarUpdate
		If ($BackupFromFileStatus -eq $True) {
			Write-Host "`nBackups complete.`n" -ForegroundColor "Yellow"
		}
	}
	ElseIf (($InputPath.Length) -gt 0 -and ($OutputPath.Length) -gt 0) {
		BackupFolder "$InputPath" "$OutputPath" $NoTarUpdate
		If ($BackupFolderStatus -eq $True) {
			Write-Host "`nBackup complete. Backed up to: ""$OutputPath""`n" -ForegroundColor "Yellow"
		}
	}
	ElseIf (($InputPath.Length) -gt 0) {
		BackupFolder "$InputPath" "$PSScriptRoot" $NoTarUpdate
		If ($BackupFolderStatus -eq $True) {
			Write-Host "`nBackup complete. Backed up to: ""$PSScriptRoot""`n" -ForegroundColor "Yellow"
		}
	}
	Else {
		Write-Host "`n[ERROR]: Invalid parameters provided.`n" -ForegroundColor "Red" -BackgroundColor "Black"
	}
	
	Exit
}



Function MainMenu {
	$MenuOption = 99
	While ($MenuOption -ne 1 -and $MenuOption -ne 2 -and $MenuOption -ne 3 -and $MenuOption -ne 0) {
		Clear-Host
		Write-Host "==================================================================================================="
		Write-Host "                                PowerShell-Backup v$RunningVersion                                 " -ForegroundColor "Yellow"
		Write-Host "==================================================================================================="
		Write-Host "`nPlease select an option:`n" -ForegroundColor "Yellow"
		Write-Host "  1   - Backup specific folder"
		Write-Host "  2   - Backup from list"
		Write-Host "  3   - Settings"
		Write-Host "`n  0   - Exit`n" -ForegroundColor "Gray"
		$MenuOption = Read-Host "Option"
		
		Write-Host "`n==================================================================================================="
		
		Switch ($MenuOption) {
			1 {
				Write-Host "`nPlease enter the full path of the folder you wish to backup:`n" -ForegroundColor "Yellow"
				$InputPath = (Read-Host "Input Path").Trim()
				Write-Host "`n---------------------------------------------------------------------------------------------------"
				Write-Host "`nPlease enter the full path of the folder you wish to save the backup:`n" -ForegroundColor "Yellow"
				$OutputPath = (Read-Host "Output Path").Trim()
				Write-Host "`n---------------------------------------------------------------------------------------------------"
				Write-Host "`n[Optional] Enter the archive file format you wish to compress the backup to:`n"
				$OutputFormat = (Read-Host "File Format").Trim()
				Write-Host "`n---------------------------------------------------------------------------------------------------"
				
				BackupFolder "$InputPath" "$OutputPath"
				
				PauseScript
				$MenuOption = 99
			}
			2 {
				BackupFromFile "$BackupListFile"
				
				PauseScript
				$MenuOption = 99
			}
			3 {
				SettingsMenu
				
				$MenuOption = 99
			}
			0 {
				Clear-Host
				Exit
			}
			Default {
				Write-Host "`nPlease enter a valid option." -ForegroundColor "Red"
				PauseScript
			}
		}
	}
}



Function SettingsMenu {
	$MenuOption = 99
	While ($MenuOption -ne 1 -and $MenuOption -ne 2 -and $MenuOption -ne 0) {
		Clear-Host
		Write-Host "==================================================================================================="
		Write-Host "                                           Settings Menu                                           " -ForegroundColor "Yellow"
		Write-Host "==================================================================================================="
		Write-Host "`nPlease select an option:`n" -ForegroundColor "Yellow"
		Write-Host "  1   - Update backup.ps1 script file"
		If ($PSScriptRoot -ne "$InstallLocation") {
			Write-Host "  2   - Install script to: ""$InstallLocation"""
		}
		Write-Host "`n  0   - Return to Main Menu`n" -ForegroundColor "Gray"
		$MenuOption = Read-Host "Option"
		
		Write-Host "`n==================================================================================================="
		
		Switch ($MenuOption) {
			1 {
				UpdateScript
				
				PauseScript
				$MenuOption = 99
			}
			2 {
				InstallScript
				
				PauseScript
				$MenuOption = 99
			}
			0 {
				Return
			}
			Default {
				Write-Host "`nPlease enter a valid option." -ForegroundColor "Red"
				PauseScript
			}
		}
	}
}


# ======================================================================================================= #
# ======================================================================================================= #
#
# MAIN
#
# ======================================================================================================= #

If ($PSVersionTable.PSVersion.Major -lt 5) {
	Write-Host "[ERROR]: Your PowerShell installation is not version 5.0 or greater.`n        This script requires PowerShell version 5.0 or greater to function.`n        You can download PowerShell version 5.0 at:`n            https://www.microsoft.com/en-us/download/details.aspx?id=50395" -ForegroundColor "Red" -BackgroundColor "Black"
	PauseScript
	Exit
}

If ($PSScriptRoot -eq "$InstallLocation") {
	$RootFolder = $InstallLocation
}
Else {
	$RootFolder = "$PSScriptRoot"
}

If ($Install -eq $False) {
	ScriptInitialization
}

If ($CheckForUpdates -eq $True -and $Install -eq $False) {
	UpdateScript
}

If ((Test-Path "$TempFolder\powershell-backup_log.log") -eq $True) {
	If ((Get-ChildItem "$TempFolder\powershell-backup_log.log").Length -gt 25000000) {
		Get-Content "$TempFolder\powershell-backup_log.log" | Select-Object -Skip 50000 | Out-File "$TempFolder\powershell-backup_log.log"
	}
}

If ((Test-Path "$BinFolder\rclone\rclone.exe") -eq $False -and $Install -eq $False) {
	Write-Host "`nrclone.exe not found. Downloading and installing to: ""$BinFolder\rclone"" ...`n" -ForegroundColor "Yellow"
	DownloadRclone
}

If (($PSBoundParameters.Count) -gt 0) {
	$CommandLine = $True
	CommandLineMode
}
Else {
	$CommandLine = $False
	MainMenu
}

Exit


# ======================================================================================================= #
# ======================================================================================================= #






