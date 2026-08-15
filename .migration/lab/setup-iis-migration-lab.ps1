param(
    [switch]$EnableWinRM,
    [int]$SitePort = 8080,
    [string]$SiteName = "MigrationLab",
    [string]$AppPoolName = "MigrationLabPool",
    [string]$PhysicalPath = "C:\MigrationLab\wwwroot"
)

$ErrorActionPreference = "Stop"
$script:RestartRequired = $false

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from an elevated PowerShell window (Run as Administrator)."
}

function Enable-IISFeatureSafely {
    param([string]$FeatureName)

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
    if ($null -eq $feature) {
        Write-Warning "IIS feature '$FeatureName' is not available on this Windows edition; skipping."
        return
    }

    if ($feature.State -ne "Enabled") {
        Write-Host "Enabling $FeatureName ..."
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart
        if ($result.RestartNeeded) {
            $script:RestartRequired = $true
        }
    }
}

$features = @(
    "IIS-WebServerRole",
    "IIS-WebServer",
    "IIS-CommonHttpFeatures",
    "IIS-StaticContent",
    "IIS-DefaultDocument",
    "IIS-HttpErrors",
    "IIS-HttpRedirect",
    "IIS-ApplicationDevelopment",
    "IIS-NetFxExtensibility45",
    "IIS-ASPNET45",
    "IIS-ISAPIExtensions",
    "IIS-ISAPIFilter",
    "IIS-WebSockets",
    "IIS-HealthAndDiagnostics",
    "IIS-HttpLogging",
    "IIS-RequestMonitor",
    "IIS-Security",
    "IIS-RequestFiltering",
    "IIS-BasicAuthentication",
    "IIS-WindowsAuthentication",
    "IIS-Performance",
    "IIS-HttpCompressionStatic",
    "IIS-WebServerManagementTools",
    "IIS-ManagementConsole",
    "IIS-ManagementScriptingTools"
)

foreach ($feature in $features) {
    Enable-IISFeatureSafely -FeatureName $feature
}

if ($script:RestartRequired) {
    Write-Host ""
    Write-Warning "Windows reports that a restart is required to finish installing IIS components."
    Write-Host "REBOOT WINDOWS NOW. After signing back in, open PowerShell as Administrator and run this same script again."
    Write-Host "No IIS site configuration will be attempted until the restart is complete."
    return
}

$appCmd = Join-Path $env:WINDIR "System32\inetsrv\appcmd.exe"
if (-not (Test-Path $appCmd)) {
    Write-Host ""
    Write-Warning "IIS AppCmd.exe is still unavailable."
    Write-Host "Expected path: $appCmd"
    Write-Host "Current IIS feature states:"
    Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole,IIS-WebServerManagementTools,IIS-ManagementScriptingTools |
        Select-Object FeatureName, State |
        Format-Table -AutoSize
    throw "IIS management components are not fully installed. If you have already rebooted, send the feature-state table above for diagnosis."
}

New-Item -Path $PhysicalPath -ItemType Directory -Force | Out-Null
New-Item -Path "C:\MigrationLab\backups" -ItemType Directory -Force | Out-Null
Set-Content -Path (Join-Path $PhysicalPath "index.html") -Encoding UTF8 -Value '<h1>IIS Migration Lab is running</h1>'

Write-Host "Configuring IIS application pool '$AppPoolName' ..."
$appPool = & $appCmd list apppool "/name:$AppPoolName"
if (-not $appPool) {
    & $appCmd add apppool "/name:$AppPoolName"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create IIS application pool '$AppPoolName'."
    }
}

Write-Host "Configuring IIS site '$SiteName' on port $SitePort ..."
$site = & $appCmd list site "/name:$SiteName"
if (-not $site) {
    $binding = "http/*:${SitePort}:"
    & $appCmd add site "/name:$SiteName" "/bindings:$binding" "/physicalPath:$PhysicalPath"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create IIS site '$SiteName'."
    }
}

& $appCmd set app "$SiteName/" "/applicationPool:$AppPoolName"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to assign application pool '$AppPoolName' to site '$SiteName'."
}

if ($EnableWinRM) {
    Write-Warning "LAB ONLY: enabling PowerShell remoting/WinRM on this laptop."
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
}

Start-Service W3SVC

Write-Host ""
Write-Host "IIS lab ready."
Write-Host "Test URL: http://localhost:$SitePort/"
Write-Host "Physical path: $PhysicalPath"
Write-Host "Backup path: C:\MigrationLab\backups"
Write-Host ""

$aspNetCoreModule = "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll"
if (-not (Test-Path $aspNetCoreModule)) {
    Write-Warning "ASP.NET Core Module not detected. Install the matching .NET Hosting Bundle after IIS is enabled."
} else {
    Write-Host "ASP.NET Core Module detected."
}
