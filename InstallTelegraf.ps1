<#
.SYNOPSIS
  Installs Windows Telegraf agent and relevant config.
.DESCRIPTION
  Installs/updates Telegraf agent, output plugin, and all relevant input plugins from a network location.
.PARAMETER Source
  Path to network share (or other) containing Telegraf source (agent, configurations, etc.).
  Defaults to the script's parent directory.
.PARAMETER Destination
  Path to Telegraf destination directory. Defaults to C:\Program Files\Telegraf
.PARAMETER LogPath
  Path to log file. Defaults to C:\InstallTelegraf.log
.PARAMETER WhatIf
  PowerShell default WhatIf param.
.PARAMETER Confirm
  PowerShell default Confirm param.
.PARAMETER Verbose
  PowerShell default Verbose param.
.INPUTS
  None
.OUTPUTS
  Log file stored in C:\TelegrafInstall.log or path specified with LogPath parameter
.NOTES
  Version:				1.3
  Author:				tigattack
  Modification Date:	10/05/2021
  Purpose/Change:		Report final result and send all other output to verbose pipeline.
.EXAMPLE
  InstallTelegraf.ps1 -Source \\path\to\share -Destination C:\custom\path -LogPath C:\Windows\TEMP\InstallTelegraf.log
#>

[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]

param (
	[Alias('Source')]
    [Parameter(Mandatory = $False)][ValidateNotNullOrEmpty()]
    [string]$telegrafSource = "$PSScriptRoot",

	[Alias('Destination')]
    [Parameter(Mandatory = $False)][ValidateNotNullOrEmpty()]
    [string]$telegrafDest = "C:\Program Files\Telegraf",

    [Parameter(Mandatory = $False)][ValidateNotNullOrEmpty()]
    [string]$LogPath = "C:\InstallTelegraf.log"
)

# Configure
$telegrafBinarySum = "$($telegrafSource)\telegraf.exe.sha256sum"
$telegrafConfDestDir = "$($telegrafDest)\telegraf.d"

$telegrafConfSource = @{
    base = "$($telegrafSource)\telegraf.conf";
    binary = "$($telegrafSource)\telegraf.exe";
    sysMetrics = "$($telegrafSource)\telegraf-system-metrics.conf";
    adds = "$($telegrafSource)\telegraf-adds.conf";
	dns = "$($telegrafSource)\telegraf-dns.conf";
    dfsn = "$($telegrafSource)\telegraf-dfsn.conf";
    dfsr = "$($telegrafSource)\telegraf-dfsr.conf"
}

$telegrafConfDest = @{
    base = "$($telegrafDest)\telegraf.conf";
    binary = "$($telegrafDest)\telegraf.exe";
    sysMetrics = "$($telegrafConfDestDir)\telegraf-system-metrics.conf";
    adds = "$($telegrafConfDestDir)\telegraf-adds.conf";
	dns = "$($telegrafConfDestDir)\telegraf-dns.conf";
    dfsn = "$($telegrafConfDestDir)\telegraf-dfsn.conf";
    dfsr = "$($telegrafConfDestDir)\telegraf-dfsr.conf"
}

$copyMsg = @{
    noMatch = "File does not match source: ";
    noExist = "File does not exist: ";
    match = "File exists and matches source. Ignoring: "
}

$created = 0
$updated = 0
$ignored = 0

if($PSCmdlet.ShouldProcess(
	"Existing Telegraf configuration will be scanned. If found and if necessary it will be updated, otherwise it will be installed and started.",
	$env:computername,
	"Install/update Telegraf and configuration")
	) {

	# Start logging
	Start-Transcript -Path $LogPath | Out-Null

	# Check files and copy/overwrite if necessary.
	Try {

		Write-Verbose "==== Testing base configuration ===="

		## Check if Telegraf destination directory exists
		If ( -not ($telegrafDest | Test-Path)) {

			Write-Verbose "Directory does not exist: $telegrafDest"
			Write-Verbose "Creating: $telegrafDest"
			Write-Verbose "Creating: $telegrafConfDestDir"
			New-Item -ItemType Directory -Path $telegrafConfDestDir
			$created += 1
		}

		Else {
			Write-Verbose "Directory exists and matches source. Ignoring: $telegrafDest"
			$ignored += 1
		}

		## Check if Telegraf agent exists and matches source
		If ($telegrafConfDest.binary | Test-Path) {
			$binaryMatch = (Get-FileHash -Algorithm SHA256 $telegrafConfDest.binary).Hash -match (Get-Content -Path $telegrafBinarySum)

			# Overwrite agent if no match
			If ( -not $binaryMatch ) {
				Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.binary)"
				Write-Verbose "Copying: $($telegrafConfSource.binary)"
				Copy-Item -Path $telegrafConfSource.binary -Destination $telegrafConfDest.binary -Force
				$updated += 1
			}

			Else {
				Write-Verbose "$($copyMsg.match) $($telegrafConfDest.binary)"
				$ignored += 1
			}
		}

		Else {
			# Copy agent if no exist
			Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.binary)"
			Write-Verbose "Copying: $($telegrafConfSource.binary)"
			Copy-Item -Path $telegrafConfSource.binary -Destination $telegrafConfDest.binary
			$created += 1
		}

		## Check if base config exists and matches source
		If ($telegrafConfDest.base | Test-Path ) {
			$baseConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.base)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.base)).Hash

			# Overwrite base config if no match
			If ( -not ($baseConfMatch)) {
				Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.base)"
				Write-Verbose "Copying: $($telegrafConfSource.base)"
				Copy-Item -Path ($telegrafConfSource.base) -Destination $telegrafConfDest.base -Force
				$updated += 1
			}

			Else {
				Write-Verbose "$($copyMsg.match) $($telegrafConfDest.base)"
				$ignored += 1
			}
		}

		## Copy base config if no exist
		Else {
			Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.base)"
			Write-Verbose "Copying: $($telegrafConfSource.base)"
			Copy-Item -Path ($telegrafConfSource.base) -Destination $telegrafConfDest.base
			$created += 1
		}

		## Check if system metrics config exists and matches source
		If ($telegrafConfDest.sysMetrics | Test-Path ) {
			$sysMetricsConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.sysMetrics)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.sysMetrics)).Hash

			# Overwrite system metrics config if no match
			If ( -not ($sysMetricsConfMatch)) {
				Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.sysMetrics)"
				Write-Verbose "Copying: $($telegrafConfSource.sysMetrics)"
				Copy-Item -Path ($telegrafConfSource.sysMetrics) -Destination $telegrafConfDest.sysMetrics -Force
				$updated += 1
			}

			Else {
				Write-Verbose "$($copyMsg.match) $($telegrafConfDest.sysMetrics)"
				$ignored += 1
			}
		}

		## Copy system metrics config if no exist
		Else {
			Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.sysMetrics)"
			Write-Verbose "Copying: $($telegrafConfSource.sysMetrics)"
			Copy-Item -Path ($telegrafConfSource.sysMetrics) -Destination $telegrafConfDest.sysMetrics
			$created += 1
		}

		Write-Verbose "==== Testing optional configuration and candidacy ===="

		## Check if machine is DC, config exists, and config matches source
		Write-Verbose "Getting computer's DomainRole."
		$domainRole = Get-CimInstance -Class Win32_ComputerSystem | Select-Object -ExpandProperty DomainRole
		If ($domainRole -match "4|5") {
			Write-Verbose "Machine is candidate for AD DS config."

			## Domain Controller config
			If ($telegrafConfDest.adds | Test-Path) {
				$dcConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.adds)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.adds)).Hash
				If ( -not $dcConfMatch ) {
					Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.adds)"
					Write-Verbose "Copying: $($telegrafConfSource.adds)"
					Copy-Item -Path $telegrafConfSource.adds -Destination $telegrafConfDest.adds -Force
					$updated += 1
				}

				Else {
					Write-Verbose "$($copyMsg.match) $($telegrafConfDest.adds)"
					$ignored += 1
				}
			}

			Else {

				Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.adds)"
				Write-Verbose "Copying: $($telegrafConfSource.adds)"
				Copy-Item -Path $telegrafConfSource.adds -Destination $telegrafConfDest.adds
				$created += 1
			}
		}

		## Check if DNS service exists, config exists, and config matches source
		If (Get-Service DNS -ErrorAction SilentlyContinue) {
			Write-Verbose "Machine is candidate for DNS config."

			## DNS config
			If ($telegrafConfDest.dns | Test-Path) {
				$dcConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.dns)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.dns)).Hash
				If ( -not $dcConfMatch ) {
					Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.dns)"
					Write-Verbose "Copying: $($telegrafConfSource.dns)"
					Copy-Item -Path $telegrafConfSource.dns -Destination $telegrafConfDest.dns -Force
					$updated += 1
				}

				Else {
					Write-Verbose "$($copyMsg.match) $($telegrafConfDest.dns)"
					$ignored += 1
				}
			}

			Else {

				Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.dns)"
				Write-Verbose "Copying: $($telegrafConfSource.dns)"
				Copy-Item -Path $telegrafConfSource.dns -Destination $telegrafConfDest.dns
				$created += 1
			}
		}

		## Check if DFSR service exists, config exists, and config matches source
		If (Get-Service DFSR -ErrorAction SilentlyContinue) {
			Write-Verbose "Machine is candidate for DFSR config."

			## DFSR config
			If ($telegrafConfDest.dfsr | Test-Path ) {

				$dfsrConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.dfsr)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.dfsr)).Hash

				If ( -not $dfsrConfMatch ) {
					Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.dfsr)"
					Write-Verbose "Copying: $($telegrafConfDest.dfsr)"
					Copy-Item -Path $telegrafConfSource.dfsr -Destination $telegrafConfDest.dfsr -Force
					$updated += 1
				}

				Else {
					Write-Verbose "$($copyMsg.match) $($telegrafConfDest.dfsr)"
					$ignored += 1
				}
			}

			Else {

				Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.dfsr)"
				Write-Verbose "Copying: $($telegrafConfDest.dfsr)"
				Copy-Item -Path ($telegrafConfSource.dfsr) -Destination "$telegrafConfDestDir\"
				$created += 1
			}
		}

		## Check if DFSN service exists, config exists, and config matches source
		If (Get-Service Dfs -ErrorAction SilentlyContinue) {
			Write-Verbose "Machine is candidate for DFSN config."

			## DFSN config
			If ($telegrafConfDest.dfsn | Test-Path) {
				$dfsnConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.dfsn)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.dfsn)).Hash
				If ( -not $dfsnConfMatch ) {

					Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.dfsn)"
					Write-Verbose "Copying: $($telegrafConfSource.dfsn)"
					Copy-Item -Path $telegrafConfSource.dfsn -Destination $telegrafConfDest.dfsn -Force
					$updated += 1
				}

				Else {
					Write-Verbose "$($copyMsg.match) $($telegrafConfDest.dfsn)"
					$ignored += 1
				}
			}

			Else {
				Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.dfsn)"
				Write-Verbose "Copying: $($telegrafConfSource.dfsn)"
				Copy-Item -Path $telegrafConfSource.dfsn -Destination $telegrafConfDest.dfsn
				$created += 1
			}
		}
	}

	Catch {
		Throw $_.Exception.Message
	}

	# Test config if anything has changed
	If (($created -gt 0) -or ($updated -gt 0)) {
		Write-Verbose "Testing Telegraf config."
		Try {
			(& $telegrafConfDest.binary --config-directory ($telegrafConfDestDir) --test) 2>&1 | Out-Null
		}
		Catch {
			Write-Warning 'Failed to run Telegraf configuration test.'
			Throw $_.Exception.Message
		}

		## If config test fail
		If ($LastExitCode -ne '0') {
			Write-Verbose 'Telegraf config test failed. Exiting.'
			Break
		}

		## If config test success but service not exist
		Elseif (($LastExitCode -eq '0') -and (-not (Get-Service Telegraf -ErrorAction SilentlyContinue))) {
			Write-Verbose "Telegraf config test successed."
			Write-Output "Installing and starting Telegraf service."
			# Install and start service
			Try {
				& $telegrafConfDest.binary --service install --config-directory ($telegrafConfDestDir)
				$created += 1
				Start-Service Telegraf
			}
			Catch {
				Write-Warning 'Failed to install and start Telegraf service.'
				Throw $_.Exception.Message
			}
		}

		## If config test success and service exist
		Elseif (($LastExitCode -eq '0') -and (Get-Service Telegraf -ErrorAction SilentlyContinue)) {
			Write-Verbose "Telegraf config test succeded."
			Write-Verbose "Telegraf service is already installed; Restarting."
			Try {
				Restart-Service Telegraf
			}
			Catch {
				Write-Warning 'Failed to start Telegraf service.'
				Throw $_.Exception.Message
			}
		}
	}

	# Output result
	$result = @{
		'Created' = $created;
		'Updated' = $updated;
		'Ignored' = $ignored
	}
	Write-Output "`nSuccessfully completed. Status:" $($result.Keys |
		Select-Object @{Label='Action';Expression={$_}},@{Label='Count';Expression={$result.$_}} |
		Format-Table -AutoSize
	)

	# Stop logging
	Stop-Transcript | Out-Null
}
