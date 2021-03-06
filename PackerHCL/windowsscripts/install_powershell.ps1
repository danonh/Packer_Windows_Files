$ErrorActionPreference = 'Stop'
$ProgressPreference = "SilentlyContinue"
if ($Env:PACKER_VERBOSE) { $VerbosePreference = "Continue" }

. A:\utilities.ps1

function Start-WindowsUpdateService () {
    if ((Get-Service -Name wuauserv).Status -eq "Stopped") {
        Get-Service -Name wuauserv | Start-Service
        (Get-Service -Name wuauserv).WaitForStatus("Running", "00:03:00")
    }
}

function Stop-WindowsUpdateService () {
    if ((Get-Service -Name wuauserv).Status -eq "Running") {
        Get-Service -Name wuauserv | Stop-Service
        (Get-Service -Name wuauserv).WaitForStatus("Stopped", "00:03:00")
    }
}

function Get-PowerShell ($Source, $Destination, $Checksum) {
    Write-Output -InputObject "", "==> Downloading installer..."
    $startTime = Get-Date
    (New-Object System.Net.WebClient).DownloadFile($Source, $Destination)
    Write-Output -InputObject "Time taken: $((Get-Date).Subtract($startTime).Seconds) second(s)"

    if (-not (Test-Path -Path $Destination)) {
        Write-Output -InputObject "Downloaded file not found."
        exit 1
    }

    if ((Get-FileHash -Path $Destination -Algorithm SHA256).Hash.ToLower() -ne $Checksum) {
        Write-Output -InputObject "Checksum does not match."
        exit 1
    }

    if ($Destination.EndsWith(".zip")) {
        try {
            $shellApplication = New-Object -Com Shell.Application
            $zipPackage = $shellApplication.NameSpace($file)
            $destinationFolder = $shellApplication.NameSpace("$env:SystemRoot\Temp")
            $destinationFolder.CopyHere($zipPackage.Items(), 0x10)
        }
        catch {
            throw "Unable to unzip package using built-in compression. Error: `n $_"
        }
    }
}

function Expand-MsuFile ($Package) {
    Write-Output -InputObject "", "==> Extracting '$Package'..."
    $result = Invoke-Process -FilePath "$env:SystemRoot\System32\wusa.exe" -ArgumentList "$env:SystemRoot\Temp\$Package", "/extract:$env:SystemRoot\Temp", "/log:$env:SystemRoot\Temp\$($Package.Replace(".msu", ".log"))"

    if ($result -ne 0) {
        Get-Content -Path "$env:SystemRoot\Temp\$($Package.Replace(".msu", ".log"))"
        Get-ChildItem -Path "$env:SystemRoot\Temp"
        Write-Output -InputObject "Wusa Error: $($result)"
        exit $result
    }
}

function Install-CabFile ($Package) {
    Write-Output -InputObject "", "==> Installing '$Package'..."
    $result = Invoke-Process -FilePath "$env:SystemRoot\System32\Dism.exe" -ArgumentList '/online', '/add-package', "/PackagePath:$env:SystemRoot\Temp\$Package", '/Quiet', '/NoRestart'
    if (0, 3010 -notcontains $result) {
        Get-Content -Path "$env:SystemRoot\Logs\DISM\dism.log"
        Write-Output -InputObject "", "Dism Error: $($result)"
        exit $result
    }
}

$powershellVersion = (Get-PowerShellVersion).Split('.')[0..1] -join '.'
$osVersion = (Get-OperatingSystemVersion).Split('.')[0..1] -join '.'

Write-Output -InputObject "Operating System Version: $osVersion"
Write-Output -InputObject "Current PowerShell Version: $powershellVersion"
switch ($osVersion) {
    '6.1' {
        if ($env:PROCESSOR_ARCHITECTURE -eq 'x86') {
            $url = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7-KB3191566-x86.zip'
            $checksum = 'eb7e2c4ce2c6cb24206474a6cb8610d9f4bd3a9301f1cd8963b4ff64e529f563'
            $output = "$env:SystemRoot\Temp\Win7-KB3191566-x86.zip"
        }
        else {
            $url = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7AndW2K8R2-KB3191566-x64.zip'
            $checksum = 'f383c34aa65332662a17d95409a2ddedadceda74427e35d05024cd0a6a2fa647'
            $output = "$env:SystemRoot\Temp\Win7AndW2K8R2-KB3191566-x64.zip"
        }
    }
    '6.2' {
        if ($env:PROCESSOR_ARCHITECTURE -eq 'x86') {
            throw "Unsupported combination."
        }
        else {
            $url = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/W2K12-KB3191565-x64.msu'
            $checksum = '4a1385642c1f08e3be7bc70f4a9d74954e239317f50d1a7f60aa444d759d4f49'
            $output = "$env:SystemRoot\Temp\W2K12-KB3191565-x64.msu"
        }
    }
    '6.3' {
        if ($env:PROCESSOR_ARCHITECTURE -eq 'x86') {
            $url = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win8.1-KB3191564-x86.msu'
            $checksum = 'f3430a90be556a77a30bab3ac36dc9b92a43055d5fcc5869da3bfda116dbd817'
            $output = "$env:SystemRoot\Temp\Win8.1-KB3191564-x86.msu.msu"
        }
        else {
            $url = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win8.1AndW2K12R2-KB3191564-x64.msu'
            $checksum = 'a8d788fa31b02a999cc676fb546fc782e86c2a0acd837976122a1891ceee42c0'
            $output = "$env:SystemRoot\Temp\Win8.1AndW2K12R2-KB3191564-x64.msu"
        }
    }
    Default {
        exit 0
    }
}

if ($PSVersionTable.PSVersion.Major -ge 5) {
    Write-Output -InputObject "Not installing PowerShell as $powershellVersion is already installed."
    exit 0
}

Get-PowerShell -Source $url -Destination $output -Checksum $checksum
Start-WindowsUpdateService

switch ($osVersion) {
    '6.1' {
        # WSUSSCAN.cab
        # Windows6.1-3191566-x64-pkgProperties.txt
        # PkgInstallOrder.txt
        # Windows6.1-3191566-x64.xml
        # Windows6.1-KB2809215-x64.cab
        # Windows6.1-KB2872035-x64.cab
        # Windows6.1-KB2872047-x64.cab
        # Windows6.1-KB3033929-x64.cab
        # Windows6.1-KB3191566-x64.cab
        Expand-MsuFile -Package "Win7AndW2K8R2-KB3191566-x64.msu"
        Install-CabFile -Package "Windows6.1-KB2809215-x64.cab"
        Install-CabFile -Package "Windows6.1-KB2872035-x64.cab"
        Install-CabFile -Package "Windows6.1-KB2872047-x64.cab"
        Install-CabFile -Package "Windows6.1-KB3033929-x64.cab"
        Install-CabFile -Package "Windows6.1-KB3191566-x64.cab"
    }
    '6.2' {
        # WSUSSCAN.cab
        # Windows8-RT-KB3191565-x64.cab
        # Windows8-RT-KB3191565-x64-pkgProperties.txt
        # Windows8-RT-KB3191565-x64.xml
        Expand-MsuFile -Package "W2K12-KB3191565-x64.msu"
        Install-CabFile -Package "Windows8-RT-KB3191565-x64.cab"
    }
    '6.3' {
        # WSUSSCAN.cab
        # WindowsBlue-KB3191564-x64.cab
        # WindowsBlue-KB3191564-x64-pkgProperties.txt
        # WindowsBlue-KB3191564-x64.xml
        Expand-MsuFile -Package "Win8.1AndW2K12R2-KB3191564-x64.msu"
        Install-CabFile -Package "WindowsBlue-KB3191564-x64.cab"
    }
}

Stop-WindowsUpdateService

exit 0