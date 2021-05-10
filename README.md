# Telegraf Deployment Script

This is a Telegraf deployment script for Windows Server* environments.

The script will install a base configuration which includes your output plugin and a comprehensive system metrics input plugin configuration.  
It will then scan the system to determine candidacy for additional input plugins as follows:

| Role                             	| Configuration Applied  	|
|----------------------------------	|------------------------	|
| Active Directory Domain Services 	| `telegraf-adds.conf` ** 	|
| DFS Namespaces                   	| `telegraf-dfsn.conf`   	|
| DFS Replication                  	| `telegraf-dfsr.conf`   	|
| DNS Server                       	| `telegraf-dns.conf`    	|

Suggested script deployment method: Group Policy computer start-up script.

\* While this script is primarily designed for Windows Server, it will still work for Windows clients, the only difference being the additional configurations in the table above will never be installed (i.e. only the output plugin and system metrics input plugin).  
\** All of the above configurations are typically (but not always) applied to domain controllers since they commonly have all of the mentioned roles installed.

## Requirements

* PowerShell 5.1 or higher.
* Administrator privileges.
* A network share with the following files in a flat structure:
    *  `telegraf.exe`
    *  `telegraf.exe.sha256sum` *
    * `telegraf.conf`
    * `telegraf-adds.conf`
    * `telegraf-dfsn.conf`
    * `telegraf-dfsr.conf`
    * `telegraf-dns.conf`
    * `telegraf-system-metrics.conf`

\* This file must contain **only** the SHA256 sum of `telegraf.exe` (e.g. the SHA256 sum for `telegraf-1.18.2_windows_amd64.exe` is `5a60cbd66787dcb5cb32faf206a7b0623501f5e4157fab9ec69aa1a956532cc5`).

## Setup

1. Download all the files in this folder to your desired source location (i.e. a network path).  
    This can be done by running the commands below in PowerShell *  
    ```PowerShell
    cd <desired config source location> # Make sure you change this
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest "https://github.com/tigattack/Scripts-Public/archive/refs/heads/master.zip" -OutFile "$env:TEMP\Scripts-Public-master.zip"
    Expand-Archive -Path "$env:TEMP\Scripts-Public-master.zip" -DestinationPath "$env:TEMP\"
    Remove-Item "$env:TEMP\Scripts-Public-master.zip"
    Move-Item "$env:TEMP\Scripts-Public-master\InstallTelegraf\" .
    Remove-Item "$env:TEMP\Scripts-Public-master" -Recurse
    ```
2. Download the latest Telegraf release for Windows from [Telegraf's GitHub releases](https://github.com/influxdata/telegraf/releases).
3. Extract the EXE from the downloaded ZIP and move it to the source location.
4. Rename the EXE to `telegraf.exe`.
5. Open PowerShell, cd to the source directory (e.g. `cd \\path\to\share`) ,and run the following command:  
    ```PowerShell
    (Get-FileHash -Algorithm SHA256 ".\telegraf.exe").Hash | Out-File ".\telegraf.exe.sha256sum"
    ```
6. Configure your output plugin and any other Telegraf agent settings `telegraf.conf`.

Ready to go!

\* This little script is entirely safe. It instructs PowerShell to use TLS1.2 (allowing it to download from a secure (HTTPS) URL), downloads a ZIP of this repository to a temporary location, extracts the ZIP, removes the ZIP, moves this project into your destination directory, then removes the extracted directory.  
However, if you don't trust it, please feel free perform a manual download of all the files in this folder (except `README.md`).

## Usage

### Example

```PowerShell
InstallTelegraf.ps1 -Source \\path\to\share -Destination C:\custom\path -LogPath C:\Windows\TEMP\InstallTelegraf.log
```

### Parameters

| Parameter          	| Type   	| Description                                                                                                                	|
|--------------------	|--------	|----------------------------------------------------------------------------------------------------------------------------	|
| Source             	| String 	| Path to network share containing Telegraf source (agent, configurations, etc.). Defaults to the script's parent directory. 	|
| Destination        	| String 	| Path to Telegraf destination directory. Defaults to 'C:\Program Files\Telegraf'.                                           	|
| InstallService     	| Switch 	| Defaults to true but can be used to disable the installation of the Telegraf service (i.e. `-InstallService:$false`).      	|
| ServiceName        	| String 	| Telegraf service name. Defaults to 'telegraf'.                                                                             	|
| ServiceDisplayName 	| String 	| Telegraf service display name. Defaults to 'Telegraf'.                                                                     	|
| LogPath            	| String 	| Path to log file. Defaults to "C:\InstallTelegraf.log".                                                                    	|
| WhatIf             	| Switch 	| Performs a dry run.                                                                                                        	|
| Confirm            	| Switch 	| Prompts user for confirmation before taking action.                                                                        	|
| Verbose            	| Switch 	| Enables verbose output.                                                                                                    	|
