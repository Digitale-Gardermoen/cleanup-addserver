param (
  [String]$localPath,
  [String]$sharePath,
  [String]$aUser,
  [String]$aPass,
  [String]$apiURL
)
# this script is for installing a new server into the solution
# run this with the user that is intended to run the cleanup script
# this script created resources on the server based on the user that runs it

# check if the localPath variable is given, if not just use the default
if (!$localPath) {
  $localPath = "C:\Cleanup"
}

# check if the sharepath is given, if not then ask for it
if (!$sharePath) {
  $sharePath = Read-Host "input share path for the cleanup script"
}

if (!$apiURL) {
  $apiURL = Read-Host "Input API URL"
}

# check if the api user credentials are given
# currently it will ask for credentials instead of finding them elsewhere.
if ((!$aUser) -or (!$aPass)) {
  $aUser = Read-Host "Input API username"
  $aPass = Read-Host "Input API password"
}

# move files to a new folder located on the root
Write-Host "Checking folder and copying file"
try {
  $folder = Get-ChildItem -Path $localPath -Force -ErrorAction SilentlyContinue
  if (!$folder) {
    New-Item -Path ("$($localPath.Split('\')[0])\") -Name ($localPath.Split('\')[1]) -ItemType Directory
    Copy-Item -Path ".\cleanup.ps1" -Destination $localPath
  }
  else {
    $file = Get-ChildItem -Path $localPath
    if (!$file) {
      Copy-Item -Path ".\cleanup.ps1" -Destination $localPath
    }
  }
}
catch {
  Write-Host "caught error while moving script"
  Write-Host $Error
}

# create a config file with the given data
Write-Host "Creating config file"
try {
  $config = @{
    url = $apiURL
    share = $sharePath
  }
  $file = Get-ChildItem -Path $localPath | Where-Object { $_.Name -eq "config" }
  if (!$file) {
    $config | ConvertTo-Json | Out-File -FilePath "$($localPath)\config.json"
    Write-Host "Created config file: $($localPath)\config.json"
  }
}
catch {
  Write-Host "caught error while saving config"
  Write-Host $Error
}

# create credentials for contacting the API
Write-Host "Creating credentials"
.\createCredentials.ps1 -localPath $localPath -username $aUser -secret $aPass

# add the server to the API
Write-Host "Adding server to the API"
.\newServer.ps1 -localPath $localPath

# create a scehduled task that runs the cleanup script
Write-Host "creating scheduled task"
try {
  $action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "$($localPath)\cleanup.ps1 -ExecutionPolicy Bypass"
  $trigger = New-ScheduledTaskTrigger -Daily -At '01:00' # this is currently hardcoded as i dont want to create a function that checks the wanted trigger
  $principal = New-ScheduledTaskPrincipal "$($env:USERDOMAIN)\$($env:USERNAME)"
  $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1)
  $task = New-ScheduledTask `
    -Action $action `
    -Principal $principal `
    -Trigger $trigger `
    -Settings $settings
  Register-ScheduledTask `
    -TaskName "cleanup" `
    -InputObject $task `
    -User "NT AUTHORITY\SYSTEM" `
    -RunLevel 'Highest' `
    -Force `
    -ErrorAction Stop `
    -ErrorVariable taskerror
}
catch {
  Write-Host "caught error while setting up task"
  Write-Host $taskerror
}