param (
  [String]$localPath
)

if (!$localPath) {
  $localPath = "."
}

try {
  $cred = Import-Clixml -Path "$($localpath)\Credentials_$($env:USERNAME)_$($env:COMPUTERNAME).xml" -ErrorAction Stop -ErrorVariable credentialError
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
  $config = Get-Content -Path "$($localpath)\config.json" -ErrorAction Stop -ErrorVariable configError
  $config = ($config|ConvertFrom-Json)
}
catch {
  Write-host "Error getting config file"
  if (!$config) {
    Write-Host "File does not exist."
  }
  Write-Host $configError
  Exit
}

$uri = "$($config.url)/addserver"
$body = @{ serverName = $env:COMPUTERNAME }


try {
  Invoke-RestMethod `
    -uri $uri `
    -Credential $cred `
    -Method 'POST' `
    -Body ($body|ConvertTo-Json) `
    -ContentType 'application/json' `
    -ErrorAction Stop `
    -ErrorVariable postError
}
catch {
  Write-Host $postError
}