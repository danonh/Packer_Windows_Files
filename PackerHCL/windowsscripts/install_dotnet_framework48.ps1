Invoke-WebRequest https://go.microsoft.com/fwlink/?linkid=2088631 -OutFile C:\Windows\Temp\dotnet.4.8.exe # Download from MS
Write-Host "Installing 4.8"
Start-Process C:\Windows\Temp\dotnet.4.8.exe -ArgumentList "/q /norestart /log C:\Windows\Temp" -Wait #Fire a new process to install silently
Write-Host "Installed 4.8 $LASTEXITCODE"