param(
    [switch]$EnableWinRM,
    [int]$SitePort = 8080,
    [string]$SiteName = "MigrationLab",
    [string]$AppPoolName = "MigrationLabPool",
    [string]$PhysicalPath = "C:\MigrationLab\wwwroot"
)

$ErrorActionPreference = "Stop"

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
        Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart | Out-Null
    }
}

$features = @(
    "IIS-WebServerRole","IIS-WebServer","IIS-CommonHttpFeatures","IIS-StaticContent",
    "IIS-DefaultDocument","IIS-HttpErrors","IIS-HttpRedirect","IIS-ApplicationDevelopment",
    "IIS-NetFxExtensibility45","IIS-ASPNET45","IIS-ISAPIExtensions","IIS-ISAPIFilter",
    "IIS-WebSockets","IIS-HealthAndDiagnostics","IIS-HttpLogging","IIS-RequestMonitor",
    "IIS-Security","IIS-RequestFiltering","IIS-BasicAuthentication","IIS-WindowsAuthentication",
    "IIS-Performance","IIS-HttpCompressionStatic","IIS-WebServerManagementTools","IIS-ManagementConsole"
)
foreach ($feature in $features) { Enable-IISFeatureSafely $feature }

Import-Module WebAdministration
New-Item -Path $PhysicalPath -ItemType Directory -Force | Out-Null
New-Item -Path "C:\MigrationLab\backups" -ItemType Directory -Force | Out-Null
Set-Content -Path (Join-Path $PhysicalPath "index.html") -Encoding UTF8 -Value '<h1>IIS Migration Lab is running</h1>'

if (-not (Test-Path "IIS:\AppPools\$AppPoolName")) {
    New-WebAppPool -Name $AppPoolName | Out-Null
}
if (-not (Get-Website -Name $SiteName -ErrorAction SilentlyContinue)) {
    New-Website -Name $SiteName -Port $SitePort -PhysicalPath $PhysicalPath -ApplicationPool $AppPoolName | Out-Null
}

if ($EnableWinRM) {
    Write-Warning "LAB ONLY: enabling PowerShell remoting/WinRM on this laptop."
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
}

Start-Service W3SVC
Write-Host "IIS lab ready at http://localhost:$SitePort/"
Write-Host "Physical path: $PhysicalPath"
Write-Host "Backup path: C:\MigrationLab\backups"
if (-not (Test-Path "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll")) {
    Write-Warning "ASP.NET Core Module not detected. Install the matching .NET Hosting Bundle after IIS is enabled."
}
