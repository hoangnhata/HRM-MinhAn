# Giai nen frontend vao C:\hrm\www tren VM 101
# Chay: powershell -ExecutionPolicy Bypass -File C:\hrm\install-frontend-on-vm.ps1

$ErrorActionPreference = 'Stop'
$zip = 'C:\hrm\hrm-frontend-dist.zip'
$www = 'C:\hrm\www'

if (-not (Test-Path $zip)) {
    Write-Host "Khong tim thay $zip"
    Write-Host "Copy file deploy\hrm-frontend-dist.zip len VM truoc."
    exit 1
}

New-Item -ItemType Directory -Force -Path $www | Out-Null
if (Test-Path $www) {
    Get-ChildItem $www -Force | Remove-Item -Recurse -Force
}

Expand-Archive -Path $zip -DestinationPath $www -Force
Write-Host "Da giai nen frontend vao $www"
Write-Host "Chay setup-iis-frontend.ps1 neu chua cau hinh IIS."
