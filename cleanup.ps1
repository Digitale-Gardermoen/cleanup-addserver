param (
  [String]$path
)

#param is -path "\\$($env:COMPUTERNAME)\share$\"
if (!$path) {
  Write-Host "Missing path, Exiting session"
  Exit
}

try {
  $cred = Import-Clixml -Path ".\Credentials_$($env:USERNAME)_$($env:COMPUTERNAME).xml" -ErrorAction Stop -ErrorVariable $credentialError
}
catch {
  Write-host "Error getting Credential file"
  if (!$cred) {
    Write-Host "File does not exist."
  }
  Write-Host $credentialError
  Exit
}

$uri = "https://cleanup.dgi.no/fetch/$($env:COMPUTERNAME)"

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
        $folders | Remove-Item -Force -Recurse -ErrorAction Stop -ErrorVariable $folderError
      }
      catch {
        if ($folderError) {
          Write-Host $folderError
        }
      }
    }
    try {
      $deleteUri = "https://cleanup.dgi.no/deleteone/$($env:COMPUTERNAME)/$($user)"
      Invoke-RestMethod `
        -Method "DELETE" `
        -Uri $deleteUri `
        -Credential $cred `
        -ErrorAction Stop `
        -ErrorVariable $restError
    }
    catch {
      if ($restError) {
        Write-Host $restError
      }
    }
  }
}