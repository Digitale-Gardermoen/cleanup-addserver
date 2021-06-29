<#
  .SYNOPSIS
    Cleanup script for deleting user based folder from a share
  .DESCRIPTION
    This script contacts the cleanup API and removes folders based on username from the provided share.
    It will fetch users from the API, delete the folders, then remove users from the API one-by-one.
  .PARAMETER path
    Optional path parameter for what share to perform the script action in
  #>
[CmdletBinding()]
param (
  [Parameter(Mandatory = $false)]
  [String]$path
)

try {
  $cred = Import-Clixml -Path ".\Credentials_$($env:USERNAME)_$($env:COMPUTERNAME).xml" -ErrorAction Stop -ErrorVariable credentialError
}
catch {
  Write-host "Error getting Credential file"
  if (!$cred) {
    Write-Host "File does not exist."
  }
  Write-Host $credentialError
  Exit
}

try {
  $config = Get-Content -Path '.\config.json' -ErrorAction Stop -ErrorVariable configError
  $config = ($config | ConvertFrom-Json)
}
catch {
  Write-host "Error getting config file"
  if (!$config) {
    Write-Host "File does not exist."
  }
  Write-Host $configError
  Exit
}

if (!$path) {
  $path = $config.share
}

function writeLog {
  <#
  .SYNOPSIS
    Creates an entry in the windows log.
    The log is created with the install script
  .DESCRIPTION
    Creates an entry in the windows log.
    The log is created with the install script
  .PARAMETER eid
    The event ID for the new entry.
  .PARAMETER entry
    The Entry Type for the new entry.
  .PARAMETER msg
    The message to set in the event log.
  .EXAMPLE
    writeLog -eid 1000 -entry "Error" -msg "error message"
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [int]$eid,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [string]$entry,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [string]$msg
  )
  Write-EventLog -LogName "Cleanup" `
    -Source "Cleanup script" `
    -EventId $eid `
    -EntryType $entry `
    -RawData 10, 20 `
    -Message $msg
}

# Force TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$uri = "$($config.url)/fetch/$($env:COMPUTERNAME)"

$result = Invoke-RestMethod -Uri $uri -Credential $cred
if ($result -eq "No data") {
  Write-Host "No data, Exiting session"
  Exit
}

$result | ForEach-Object {
  if (($_.username -eq $null) -or ($_.username -eq "")) {
    Write-Host "No username, breaking loop"
    break
  }
  else {
    $user = $_.username
    $folders = Get-ChildItem -Path $path -Force | Where-Object { $($_.Name) -like "$($user).AD*" }
    if (($folders) -and ($folders.Length -gt 0)) {
      try {
        $folders | Remove-Item -Force -Recurse -ErrorAction Stop
      }
      catch {
        if ($_.Exception.Message -match "$user") {
          writeLog -eid 5000 -entry "Information" -msg "Got an Access error, trying to take ownership and resetting the security settings. Folders: `n$($folders.Name)"
    
           ForEach ($folder in $folders) {
             Invoke-Expression -Command ('TAKEOWN /f ' + "$($folder.FullName)" + ' /a /r /d Y')
             Invoke-Expression -Command ('ICACLS ' + "$($folder.FullName)" + ' /reset /T')
           }

           $folders | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue -ErrorVariable folderError
        }
        if ($folderError) {
          Write-Host $folderError
          writeLog -eid 1000 -entry "Error" -msg $folderError
        }
      }
    }

    try {
      $deleteUri = "$($config.url)/deleteone/$($env:COMPUTERNAME)/$($user)"
      Invoke-RestMethod `
        -Method "DELETE" `
        -Uri $deleteUri `
        -Credential $cred `
        -ErrorAction Stop `
        -ErrorVariable restError
    }
    catch {
      if ($restError) {
        Write-Host $restError
        writeLog -eid 2000 -entry "Error" -msg $restError
      }
    }
  }
}
