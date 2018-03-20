<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK 
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}
	
	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Mozilla'
	[string]$appName = 'Firefox'
	[string]$appVersion = '58.0.2'
	[string]$appArch = 'x64.x86'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '28/02/2018'
	[string]$appScriptAuthor = 'Pieter Jan Geutjens'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''
	
	##* Do not modify section below
	#region DoNotModify
	
	## Variables: Exit Code
	[int32]$mainExitCode = 0
	
	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.6.8'
	[string]$deployAppScriptDate = '02/06/2016'
	[hashtable]$deployAppScriptParameters = $psBoundParameters
	
	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
	
	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}
	
	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================
		
	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'
		
		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		#Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt
        Show-InstallationWelcome -CloseApps 'firefox' -AllowDefer -DeferTimes 3 -CheckDiskSpace
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		## <Perform Pre-Installation tasks here>

        Remove-MSIApplications -Name 'Mozilla Firefox'

        $UninstallerEXE = "$($envProgramFilesX86)\Mozilla Firefox\uninstall\helper.exe"
		
		if (Test-Path -Path $UninstallerEXE){
            Write-log -Message "Uninstaller Found... Removing"
			Execute-Process -Path $UninstallerEXE -Parameters "-ms" -ContinueOnError $True
			Remove-Folder -Path "$($envProgramFilesX86)\Mozilla Firefox" -ContinueOnError $True
            Remove-Folder -Path "$($envProgramData)\Mozilla" -ContinueOnError $True
        }
        
        $UninstallerEXE = "$($envProgramFiles)\Mozilla Firefox\uninstall\helper.exe"
           
		if (Test-Path -Path $UninstallerEXE){
            Write-log -Message "Uninstaller Found... Removing"
			Execute-Process -Path $UninstallerEXE -Parameters "-ms" -ContinueOnError $True
			Remove-Folder -Path "$($envProgramFilesX86)\Mozilla Firefox" -ContinueOnError $True
            Remove-Folder -Path "$($envProgramData)\Mozilla" -ContinueOnError $True
        }
        
        
		##*===============================================
		##* INSTALLATION 
		##*===============================================
		[string]$installPhase = 'Installation'
		
		## Handle Zero-Config MSI Installations

		
		## <Perform Installation tasks here>
        if ($is64Bit) {
            Execute-Process -Path 'Firefox Setup 58.0.2_x64.exe' -Parameters "/INI=$($dirSupportFiles)\Installer.ini"
            import-module '.\PinnedApplication.psm1'
            Set-PinnedApplication -Action PinToTaskBar -FilePath "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

        }
        else {
            Execute-Process -Path 'Firefox Setup 58.0.2.exe' -Parameters "/INI=$($dirSupportFiles)\Installer.ini"
        }
		start-sleep -seconds 10
        import-module '.\PinnedApplication.psm1'
    	if(test-path("C:\Program Files\Mozilla Firefox\firefox.exe"))
        {
            Set-PinnedApplication -Action PinToTaskBar -FilePath "C:\Program Files\Mozilla Firefox\firefox.exe"
        }
        else
        {
            Set-PinnedApplication -Action PinToTaskBar -FilePath "C:\Program Files (x86)\Mozilla Firefox\firefox.exe"
        }
		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'
		
		## <Perform Post-Installation tasks here>
		Copy-File -Path "$dirSupportFiles\autoconfig.js" -Destination "$($envProgramFiles)\Mozilla Firefox\defaults\pref\autoconfig.js"
		Copy-File -Path "$dirSupportFiles\mozilla.cfg" -Destination "$($envProgramFiles)\Mozilla Firefox\mozilla.cfg"

		## Display a message at the end of the install
		If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'De installatie is afgelopen.  Hou er rekening mee dat U plugins zoals E-ID Middleware opnieuw dient te installeren.' -ButtonRightText 'OK' -Icon Information -NoWait }
        
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'
		
		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'firefox'
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		## <Perform Pre-Uninstallation tasks here>
		
		
		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'
		
		## Handle Zero-Config MSI Uninstallations
        import-module '.\PinnedApplication.psm1'
    	if(test-path("C:\Program Files\Mozilla Firefox\firefox.exe"))
        {
            Set-PinnedApplication -Action UnPinFromTaskbar -FilePath "C:\Program Files\Mozilla Firefox\firefox.exe"
        }
        else
        {
            Set-PinnedApplication -Action UnPinFromTaskbar -FilePath "C:\Program Files (x86)\Mozilla Firefox\firefox.exe"
        }


        $UninstallerEXE = "$($envProgramFiles)\Mozilla Firefox\uninstall\helper.exe"
		
		# <Perform Uninstallation tasks here>
        if (Test-Path -Path $UninstallerEXE){
            Write-log -Message "Uninstaller Found... Removing"
            Execute-Process -Path $UninstallerEXE -Parameters "-ms" -ContinueOnError $True
			Start-Sleep -Seconds 10
        } else {
            Write-log -Message "Uninstaller not found... Removing files and registry items" -severity 2
            Remove-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Firefox Setup 58.0.2' -Recurse -ContinueOnError $True
            Remove-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MozillaMaintenanceService' -Recurse -ContinueOnError $True
            Remove-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Mozilla' -Recurse -ContinueOnError $True
            Remove-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\mozilla.org' -Recurse -ContinueOnError $True
            
            Stop-ServiceAndDependencies -Name 'MozillaMaintenance' -ContinueOnError $True
            try{
                (Get-WmiObject Win32_Service -filter "name='MozillaMaintenance'").Delete()
            } catch {
                write-log -Message "Not able to remove the maintenance service" -severity 2    
            }

            Remove-Folder -Path "$($envProgramFiles)\Mozilla Firefox" -ContinueOnError $True
            Remove-Folder -Path "$($envProgramData)\Mozilla" -ContinueOnError $True

        }
		
		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'
		
		## <Perform Post-Uninstallation tasks here>
		
		
	}
	
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================
	
	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}