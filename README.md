# Add cleanup to server #

## how to install ##

To install the script on a server, you run `install.ps1`.
There are a few things to be vary about before running it:

- Run the script from the directory its in, together with `cleanup.ps1`, `createCredentials.ps1` and `newServer.ps1`
- Run the script **as** the user you want/that has permission to delete folders.

### Parameters ###

When the script is ran as is, it will ask for a few parameters before it installs the script.

- `Required`  sharePath
  - A path for where the cleanup script will look for folders to delete.
- `Required`  aUser
  - This is the API user used to authenticate when requesting from the API
- `Required`  aPass
  - This is the secret for the API.
- `Required`  apiURL
  - The URL for the API, this is used together with the final script.
- _Optinonal_ localPath
  - If you want the script to be installed in another location rather than `C:\Cleanup` you can set this to the path you want.

### Scheduled task ###

The script will create a scehduled task on the server its installed on, the settings for this can be changed beforehand, but you can only do this from the script.

```Powershell
$trigger = New-ScheduledTaskTrigger -Daily -At '01:00'
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask `
  -TaskName "cleanup" `
  -InputObject $task `
  -User "NT AUTHORITY\SYSTEM" `
  -RunLevel 'Highest' `
  -Force `
  -ErrorAction Stop `
  -ErrorVariable taskerror
```

Change any of these to fit your needs.

## How it works ##

When ran, the script will create a folder in the `$localPath` location, this is `C:\Cleanup` by default. If the folder exists it will skip to it and check if the cleanup script exists. Then copy the script from the current working directory to the new direcotry. The script will also create a config file based on the parameters you give it. This file includes the URL and the share path.

Then it will create the credential file needed for doing API requests, this is installed together with the `cleanup.ps1` script. The file is named in this way: `Credentials_USERNAME_COMPUTERNAME.xml`. This is because of the way powershell creates and stores securestrings, this way you know what user created the creadential on which server.

After this the first API call will be made to add the server to the serverlist. Be sure that the port used for the api is open between the server and the API.

The last part is creating the scheduled task for the cleanup script. The task is setup with these defaults:

- ExecutionPolicy Bypass (when running script).
- Trigger Daily at 01:00.
- Execution time will not exceed 1 hour.
- Ran by user NT AUTHORITY\SYSTEM with highest priviledges

## Files ##

- `cleanup.ps1`
  - This is the script that will be ran by the task, this script does an API call to fetch all flagged users, then deletes the folders based on the username. After all folders for that user is deleted, it sends a DELETE request to the API.
- `createCredentials.ps1`
  - This is pretty much what its named, it will take the credentials provided when installing and create a credential file based on that. It will name the file with the username and the computername of which it was ran.
    - Example: `Credentials_user1_server01.xml`
- `install.ps1`
  - This file is described above.
- `newServer.ps1`
  - This script adds a server to the API by POST-ing the environment computername. It uses the credentials made during the install.