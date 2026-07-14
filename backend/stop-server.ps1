# Giải phóng port 8080 (instance Spring Boot cũ còn chạy)
$lines = netstat -ano | Select-String ':8080\s+.*LISTENING'
if (-not $lines) {
    Write-Host 'Port 8080 is free.'
    exit 0
}
$pids = $lines | ForEach-Object {
    if ($_ -match '\s+(\d+)\s*$') { [int]$Matches[1] }
} | Sort-Object -Unique
foreach ($procId in $pids) {
    Write-Host "Stopping PID $procId ..."
    taskkill /PID $procId /F 2>$null
}
Write-Host 'Done. You can run: mvn spring-boot:run'
