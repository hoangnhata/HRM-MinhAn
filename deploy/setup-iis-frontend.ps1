# Chay PowerShell **Run as Administrator** tren VM 101 (Windows Server 2019)
# Cai IIS + site frontend HRM tai C:\hrm\www, proxy /j1-api -> localhost:8080

$ErrorActionPreference = 'Stop'
$wwwRoot = 'C:\hrm\www'
$siteName = 'MinhanHRM'
$sitePort = 80
$installerDir = 'C:\hrm\installers'

function Install-IisMsi {
    param(
        [string]$Name,
        [string]$Url,
        [string]$MsiFileName,
        [string]$DllPath
    )
    if (Test-Path $DllPath) {
        Write-Host "  $Name da co." -ForegroundColor Green
        return
    }
    New-Item -ItemType Directory -Force -Path $installerDir | Out-Null
    $msi = Join-Path $installerDir $MsiFileName
    Write-Host "  Dang tai $Name..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $Url -OutFile $msi -UseBasicParsing
    Write-Host "  Dang cai $Name (im lang, doi 1-2 phut)..." -ForegroundColor Yellow
    $p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /quiet /norestart" -Wait -PassThru
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
        throw "Cai $Name that bai (exit $($p.ExitCode)). Thu cai tay tu file: $msi"
    }
    if (-not (Test-Path $DllPath)) {
        throw "Da chay MSI nhung chua thay $DllPath. Khoi dong lai may hoac cai tay."
    }
    Write-Host "  $Name cai xong." -ForegroundColor Green
}

Write-Host "=== 1. Bat IIS (neu chua co) ===" -ForegroundColor Cyan
$iis = Get-WindowsFeature Web-Server
if (-not $iis.Installed) {
    Install-WindowsFeature Web-Server, Web-Static-Content, Web-Default-Doc, Web-Http-Errors, Web-Http-Logging, Web-Stat-Compression, Web-Filtering, Web-Mgmt-Console
} else {
    Write-Host "IIS da cai."
}

Write-Host "`n=== 2. URL Rewrite + ARR (tu dong tai neu thieu) ===" -ForegroundColor Cyan
Install-IisMsi `
    -Name 'URL Rewrite' `
    -Url 'https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi' `
    -MsiFileName 'rewrite_amd64_en-US.msi' `
    -DllPath "${env:ProgramFiles}\IIS\Url Rewrite\rewrite.dll"

Install-IisMsi `
    -Name 'Application Request Routing (ARR)' `
    -Url 'https://download.microsoft.com/download/E9/E8/E9E83EFC-2186-4BAE-941C-70305361F5C2/requestRouter_amd64.msi' `
    -MsiFileName 'requestRouter_amd64.msi' `
    -DllPath "${env:ProgramFiles}\IIS\Application Request Routing\requestrouter.dll"

Import-Module WebAdministration
Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter 'system.webServer/proxy' -name 'enabled' -value 'True'

Write-Host "`n=== 3. Thu muc www ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $wwwRoot | Out-Null
if (-not (Test-Path (Join-Path $wwwRoot 'index.html'))) {
    Write-Host "Canh bao: $wwwRoot chua co index.html" -ForegroundColor Yellow
    Write-Host "Chay: powershell -ExecutionPolicy Bypass -File C:\hrm\install-frontend-on-vm.ps1"
}

Write-Host "`n=== 4. Tao site IIS ===" -ForegroundColor Cyan
if (Test-Path "IIS:\Sites\$siteName") {
    Remove-Website -Name $siteName
}
if (Test-Path "IIS:\Sites\Default Web Site") {
    Stop-Website -Name 'Default Web Site' -ErrorAction SilentlyContinue
}

New-Website -Name $siteName -PhysicalPath $wwwRoot -Port $sitePort -Force | Out-Null
Set-ItemProperty "IIS:\Sites\$siteName" -Name applicationPool -Value 'DefaultAppPool'

Write-Host "`n=== 5. Mo firewall TCP 80 ===" -ForegroundColor Cyan
$ruleName = 'HRM Frontend HTTP'
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if (-not $existing) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80 | Out-Null
}

iisreset /restart | Out-Null

Write-Host "`n=== XONG ===" -ForegroundColor Green
Write-Host "Truy cap: http://192.168.31.101/"
Write-Host "Dam bao backend dang chay (start-hrm.bat) truoc khi dang nhap."
