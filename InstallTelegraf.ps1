#Requires -Version 5.1 -RunAsAdministrator
<#
.SYNOPSIS
  Installs Windows Telegraf agent and relevant config.
.DESCRIPTION
  Installs/updates Telegraf agent, output plugin, and all relevant input plugins from a network location.
.PARAMETER Source
  Path to network share (or other) containing Telegraf source (agent, configurations, etc.).
  Defaults to the script's parent directory.
.PARAMETER Destination
  Path to Telegraf destination directory. Defaults to 'C:\Program Files\Telegraf'.
.PARAMETER InstallService
  Switch which defaults to true but can be used to disable the installation of the Telegraf service.
.PARAMETER ServiceName
  Telegraf service name. Defaults to 'telegraf'.
.PARAMETER ServiceDisplayName
  Telegraf service display name. Defaults to 'Telegraf'.
.PARAMETER LogPath
  Path to log file. Defaults to 'C:\InstallTelegraf.log'.
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
  Version:				1.5
  Author:				tigattack
  Modification Date:	16/09/2021
  Purpose/Change:		InstallService default $false.
.EXAMPLE
  InstallTelegraf.ps1 -Source \\path\to\share -Destination C:\custom\path -LogPath C:\Windows\TEMP\InstallTelegraf.log
#>

[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]

param (
	[Alias('Source')]
	[Parameter(Position=0,Mandatory = $False)][ValidateNotNullOrEmpty()]
	[string]$telegrafSource = "$PSScriptRoot",

	[Alias('Destination')]
	[Parameter(Position=1,Mandatory = $False)][ValidateNotNullOrEmpty()]
	[string]$telegrafDest = 'C:\Program Files\Telegraf',

	[Parameter(Position=2,Mandatory = $False)]
	[switch]$InstallService,

	[Parameter(Position=3,Mandatory = $False)][ValidateScript({$_ -notmatch ' '})]
	[string]$ServiceName = 'telegraf',

	[Parameter(Position=4,Mandatory = $False)][ValidateNotNullOrEmpty()]
	[string]$ServiceDisplayName = 'Telegraf',

	[Parameter(Position=5,Mandatory = $False)][ValidateNotNullOrEmpty()]
	[string]$LogPath = 'C:\InstallTelegraf.log'
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
	noMatch = 'File does not match source: ';
	noExist = 'File does not exist: ';
	match = 'File exists and matches source. Ignoring: '
}

$created = 0
$updated = 0
$ignored = 0

# Start logging
Try {
	Start-Transcript -Path $LogPath -OutVariable transcript | Out-Null
}
Catch {
	Write-Warning $_.Exception.Message
}

# Check files and copy/overwrite if necessary.
Try {

	Write-Verbose '==== Testing base configuration ===='

	## Check if Telegraf destination directory exists
	If ( -not ($telegrafDest | Test-Path)) {

		If($PSCmdlet.ShouldProcess(
				"Performing the operation `"New-Item -ItemType Directory`" on targets `"$telegrafDest`" and `"$telegrafConfDestDir`".",
				$env:computername,
				'Create destination directories')
		) {
			Write-Verbose "Directory does not exist: $telegrafDest"
			Write-Verbose "Creating: $telegrafDest"
			Write-Verbose "Creating: $telegrafConfDestDir"
			New-Item -ItemType Directory -Path $telegrafConfDestDir | Write-Debug
			$created += 1
		}
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
			If($PSCmdlet.ShouldProcess(
					$telegrafConfDest.binary,
					'Update')
			) {
				Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.binary)"
				Write-Verbose "Copying: $($telegrafConfSource.binary)"
				Copy-Item -Path $telegrafConfSource.binary -Destination $telegrafConfDest.binary -Force
				$updated += 1
			}
		}

		Else {
			Write-Verbose "$($copyMsg.match) $($telegrafConfDest.binary)"
			$ignored += 1
		}
	}

	Else {
		# Copy agent if no exist
		If($PSCmdlet.ShouldProcess(
				$telegrafConfDest.binary,
				'Copy')
		) {
			Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.binary)"
			Write-Verbose "Copying: $($telegrafConfSource.binary)"
			Copy-Item -Path $telegrafConfSource.binary -Destination $telegrafConfDest.binary
			$created += 1
		}
	}

	## Check if base config exists and matches source
	If ($telegrafConfDest.base | Test-Path ) {
		$baseConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.base)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.base)).Hash

		# Overwrite base config if no match
		If ( -not ($baseConfMatch)) {
			If($PSCmdlet.ShouldProcess(
					$telegrafConfDest.base,
					'Update')
			) {
				Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.base)"
				Write-Verbose "Copying: $($telegrafConfSource.base)"
				Copy-Item -Path ($telegrafConfSource.base) -Destination $telegrafConfDest.base -Force
				$updated += 1
			}
		}

		Else {
			Write-Verbose "$($copyMsg.match) $($telegrafConfDest.base)"
			$ignored += 1
		}
	}

	## Copy base config if no exist
	Else {
		If($PSCmdlet.ShouldProcess(
				$telegrafConfDest.base,
				'Copy')
		) {
			Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.base)"
			Write-Verbose "Copying: $($telegrafConfSource.base)"
			Copy-Item -Path ($telegrafConfSource.base) -Destination $telegrafConfDest.base
			$created += 1
		}
	}

	## Check if system metrics config exists and matches source
	If ($telegrafConfDest.sysMetrics | Test-Path ) {
		$sysMetricsConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.sysMetrics)).Hash -match `
		(Get-FileHash -Algorithm SHA256 ($telegrafConfSource.sysMetrics)).Hash

		# Overwrite system metrics config if no match
		If ( -not ($sysMetricsConfMatch)) {
			If($PSCmdlet.ShouldProcess(
					$telegrafConfDest.sysMetrics,
					'Update')
			) {
				Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.sysMetrics)"
				Write-Verbose "Copying: $($telegrafConfSource.sysMetrics)"
				Copy-Item -Path ($telegrafConfSource.sysMetrics) -Destination $telegrafConfDest.sysMetrics -Force
				$updated += 1
			}
		}

		Else {
			Write-Verbose "$($copyMsg.match) $($telegrafConfDest.sysMetrics)"
			$ignored += 1
		}
	}

	## Copy system metrics config if no exist
	Else {
		If($PSCmdlet.ShouldProcess(
				$telegrafConfDest.sysMetrics,
				'Copy')
		) {
			Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.sysMetrics)"
			Write-Verbose "Copying: $($telegrafConfSource.sysMetrics)"
			Copy-Item -Path ($telegrafConfSource.sysMetrics) -Destination $telegrafConfDest.sysMetrics
			$created += 1
		}
	}

	# Get system ProductType
	Write-Verbose "Getting system's ProductType."
	$productType = (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType

	## If Win32_OperatingSystem.ProductType indicates server
	If ($productType -ne '1') {

		Write-Verbose 'OperatingSystem ProductType indicates machine is Server; evaluating further configuration.'
		Write-Verbose '==== Testing optional configuration and candidacy ===='

		## Check if machine is DC, config exists, and config matches source
		## If Win32_OperatingSystem.ProductType indicates Domain Controller
		If ($productType -eq '2') {
			Write-Verbose 'Machine is candidate for AD DS config.'

			## Domain Controller config
			If ($telegrafConfDest.adds | Test-Path) {
				$addsConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.adds)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.adds)).Hash
				If ( -not $addsConfMatch ) {
					If($PSCmdlet.ShouldProcess(
							$telegrafConfDest.adds,
							'Update')
					) {
						Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.adds)"
						Write-Verbose "Copying: $($telegrafConfSource.adds)"
						Copy-Item -Path $telegrafConfSource.adds -Destination $telegrafConfDest.adds -Force
						$updated += 1
					}
				}

				Else {
					Write-Verbose "$($copyMsg.match) $($telegrafConfDest.adds)"
					$ignored += 1
				}
			}

			Else {

				If($PSCmdlet.ShouldProcess(
						$telegrafConfDest.adds,
						'Copy')
				) {
					Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.adds)"
					Write-Verbose "Copying: $($telegrafConfSource.adds)"
					Copy-Item -Path $telegrafConfSource.adds -Destination $telegrafConfDest.adds
					$created += 1
				}
			}
		}

		## Check if DNS service exists, config exists, and config matches source
		If (Get-Service DNS -ErrorAction SilentlyContinue) {
			Write-Verbose 'Machine is candidate for DNS config.'

			## DNS config
			If ($telegrafConfDest.dns | Test-Path) {
				$dnsConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.dns)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.dns)).Hash
				If ( -not $dnsConfMatch ) {
					If($PSCmdlet.ShouldProcess(
							$telegrafConfDest.dns,
							'Update')
					) {
						Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.dns)"
						Write-Verbose "Copying: $($telegrafConfSource.dns)"
						Copy-Item -Path $telegrafConfSource.dns -Destination $telegrafConfDest.dns -Force
						$updated += 1
					}
				}

				Else {
					Write-Verbose "$($copyMsg.match) $($telegrafConfDest.dns)"
					$ignored += 1
				}
			}

			Else {

				If($PSCmdlet.ShouldProcess(
						$telegrafConfDest.dns,
						'Copy')
				) {
					Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.dns)"
					Write-Verbose "Copying: $($telegrafConfSource.dns)"
					Copy-Item -Path $telegrafConfSource.dns -Destination $telegrafConfDest.dns
					$created += 1
				}
			}
		}

		## Check if DFSR service exists, config exists, and config matches source
		If (Get-Service DFSR -ErrorAction SilentlyContinue) {
			Write-Verbose 'Machine is candidate for DFSR config.'

			## DFSR config
			If ($telegrafConfDest.dfsr | Test-Path ) {

				$dfsrConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.dfsr)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.dfsr)).Hash

				If ( -not $dfsrConfMatch ) {
					If($PSCmdlet.ShouldProcess(
							$telegrafConfDest.dfsr,
							'Update')
					) {
						Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.dfsr)"
						Write-Verbose "Copying: $($telegrafConfDest.dfsr)"
						Copy-Item -Path $telegrafConfSource.dfsr -Destination $telegrafConfDest.dfsr -Force
						$updated += 1
					}
				}

				Else {
					Write-Verbose "$($copyMsg.match) $($telegrafConfDest.dfsr)"
					$ignored += 1
				}
			}

			Else {

				If($PSCmdlet.ShouldProcess(
						$telegrafConfDest.dfsr,
						'Copy')
				) {
					Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.dfsr)"
					Write-Verbose "Copying: $($telegrafConfDest.dfsr)"
					Copy-Item -Path ($telegrafConfSource.dfsr) -Destination "$telegrafConfDestDir\"
					$created += 1
				}
			}
		}

		## Check if DFSN service exists, config exists, and config matches source
		If (Get-Service Dfs -ErrorAction SilentlyContinue) {
			Write-Verbose 'Machine is candidate for DFSN config.'

			## DFSN config
			If ($telegrafConfDest.dfsn | Test-Path) {
				$dfsnConfMatch = (Get-FileHash -Algorithm SHA256 ($telegrafConfDest.dfsn)).Hash -match (Get-FileHash -Algorithm SHA256 ($telegrafConfSource.dfsn)).Hash
				If ( -not $dfsnConfMatch ) {

					If($PSCmdlet.ShouldProcess(
							$telegrafConfDest.dfsn,
							'Update')
					) {
						Write-Verbose "$($copyMsg.noMatch) $($telegrafConfDest.dfsn)"
						Write-Verbose "Copying: $($telegrafConfSource.dfsn)"
						Copy-Item -Path $telegrafConfSource.dfsn -Destination $telegrafConfDest.dfsn -Force
						$updated += 1
					}
				}

				Else {
					Write-Verbose "$($copyMsg.match) $($telegrafConfDest.dfsn)"
					$ignored += 1
				}
			}

			Else {

				If($PSCmdlet.ShouldProcess(
						$telegrafConfDest.dfsn,
						'Copy')
				) {
					Write-Verbose "$($copyMsg.noExist) $($telegrafConfDest.dfsn)"
					Write-Verbose "Copying: $($telegrafConfSource.dfsn)"
					Copy-Item -Path $telegrafConfSource.dfsn -Destination $telegrafConfDest.dfsn
					$created += 1
				}
			}
		}
	}
}

Catch {
	Throw $_.Exception.Message
}

# Test config if anything has changed
If (($created -gt 0) -or ($updated -gt 0) -or ($WhatIfPreference -eq $true)) {
	If($PSCmdlet.ShouldProcess(
			"$telegrafDest\*",
			'Test configuration')
	) {
		Write-Verbose 'Testing Telegraf config.'
		Try {
			# Run test
			(& $telegrafConfDest.binary --config $telegrafConfDest.base --config-directory $telegrafConfDestDir --test) 2>&1 | Write-Debug

			# If test success
			If ($LastExitCode -eq '0') {
				Write-Verbose 'Telegraf config test succeeded.'
			}
			# If test not success
			Else {
				Write-Verbose 'Telegraf config test did not succeed. Exiting.'
				Break
			}
		}
		Catch {
			Write-Warning 'Failed to run Telegraf configuration test.'
			Throw $_.Exception.Message
		}
	}

	## If config test success but service not exist
	If (($LastExitCode -eq '0') -and ($InstallService -eq $true) -and (-not (Get-Service $ServiceName -ErrorAction SilentlyContinue))) {
		If($PSCmdlet.ShouldProcess(
				$env:computername,
				'Install service')
		) {
			Write-Output "Installing and starting '$ServiceName' service."
			# Install service
			Try {
				(& $telegrafConfDest.binary --service install --service-name=$ServiceName --service-display-name="$ServiceDisplayName" `
					--config $telegrafConfDest.base --config-directory $telegrafConfDestDir) 2>&1 | Write-Debug
				$created += 1
			}
			Catch {
				Write-Warning 'Failed to install '$ServiceName' service.'
				Throw $_.Exception.Message
			}
		}

		If($PSCmdlet.ShouldProcess(
				$ServiceName,
				'Start-Service')
		) {
			# Start service
			Try {
				Start-Service $ServiceName
			}
			Catch {
				Write-Warning "Failed to start '$ServiceName' service."
				Throw $_.Exception.Message
			}
		}
	}

	## If config test success and service exist
	Elseif (($LastExitCode -eq '0') -and (Get-Service $ServiceName -ErrorAction SilentlyContinue)) {
		If($PSCmdlet.ShouldProcess(
				$ServiceName,
				'Restart service')
		) {
			Write-Verbose "Restarting '$ServiceName' service."
			Try {
				Restart-Service $ServiceName
			}
			Catch {
				Write-Warning 'Failed to start '$ServiceName' service.'
				Throw $_.Exception.Message
			}
		}
	}

	If (($created -gt 0) -or ($updated -gt 0)) {
		# Output result
		$result = @{
			'Created' = $created;
			'Updated' = $updated;
			'Ignored' = $ignored
		}
		Write-Output "`nSuccessfully completed. Status:"
		$($result.Keys |
				Select-Object @{Label='Action';Expression={$_}},@{Label='Count';Expression={$result.$_}} |
				Format-Table -AutoSize)
	}
}

Elseif ($WhatIfPreference -eq $false) {
	Write-Output "`nTelegraf agent and configuration is all up to date. No action taken.`n"
}

# Stop logging
If ($transcript) {
	Stop-Transcript | Out-Null
}
