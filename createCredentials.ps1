param (
  [string]$username,
  [String]$secret
)

if ((!$username) -or (!$secret)) {
  Write-Host "No username or secret provided."
  Exit
}

$secureString = ConvertTo-SecureString $secret -AsPlainText -Force # Convert the password to a securestring
# Create the credential object, then export it with XMLCli.
# Important that the credential file is created under the user and on the computer which it is supposed to run.
$cred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $secureString
$cred | Export-Clixml -Path ".\Credentials_$($env:USERNAME)_$($env:COMPUTERNAME).xml"