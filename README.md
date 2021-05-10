# Telegraf Deployment Script

This is a Telegraf deployment script for Windows environments.

The script will install a base configuration which includes your output plugin and a comprehensive system metrics input plugin configuration, then it will scan the system to determine candidacy for additional configuration as follows:

| Role                             	| Configuration Applied  	|
|----------------------------------	|------------------------	|
| Active Directory Domain Services 	| `telegraf-adds.conf` * 	|
| DFS Namespaces                   	| `telegraf-dfsn.conf`   	|
| DFS Replication                  	| `telegraf-dfsr.conf`   	|
| DNS Server                       	| `telegraf-dns.conf`    	|

\* Typically, but not always, all of the above also applied to a domain controller since all of the mentioned roles are commonly found on domain controllers.

Suggested script deployment method: Group Policy computer  start-up script.

## Requirements

* PowerShell 5.1 or higher.
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

1. Clone this repository to your desired source location (i.e. a network path).
2. Download the latest Telegraf release for Windows from [Telegraf's GitHub releases](https://github.com/influxdata/telegraf/releases).
3. Extract the EXE from the downloaded ZIP and move it to the source location.
4. Rename the EXE to `telegraf.exe`.
5. Open PowerShell, cd to the source directory (e.g. `cd \\path\to\share`) ,and run the following command:  
    ```PowerShell
    (Get-FileHash -Algorithm SHA256 ".\telegraf.exe").Hash | Out-File ".\telegraf.exe.sha256sum"
    ```
6. Configure your output plugin and any other Telegraf agent settings `telegraf.conf`.

Ready to go!
