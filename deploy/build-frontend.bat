@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "ROOT=%~dp0.."
set "FRONTEND=%ROOT%\frontend"
set "OUT=%ROOT%\deploy\hrm-frontend-dist.zip"

cd /d "%FRONTEND%"
if not exist package.json (
    echo Khong tim thay frontend\package.json
    exit /b 1
)

echo === Cai dependency (neu can) ===
if exist "node_modules\" (
    echo Da co node_modules — bo qua npm install.
    echo Neu can cai lai: xoa thu muc node_modules roi chay lai script.
) else (
    echo Dang npm install ^(co the mat vai phut, it khi in log^)...
    call npm install --no-fund --no-audit
    if errorlevel 1 exit /b 1
)

echo.
echo === Build production (VITE_API_URL=/j1-api — erp.benhvienminhan.com) ===
call npm run build:deploy
if errorlevel 1 exit /b 1

copy /Y "%ROOT%\deploy\frontend\web.config" "%FRONTEND%\dist\web.config" >nul

echo.
echo === Dong goi %OUT% ===
if exist "%OUT%" del /f "%OUT%"
powershell -NoProfile -Command "Compress-Archive -Path '%FRONTEND%\dist\*' -DestinationPath '%OUT%' -Force"

echo.
echo Xong. Copy file zip len VM 101:
echo   %OUT%
echo   -^> C:\hrm\www\
echo.
endlocal
