@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "ROOT=%~dp0.."
set "FRONTEND=%ROOT%\frontend"
set "OUT=%ROOT%\deploy\hrm-frontend-xampp.zip"

cd /d "%FRONTEND%"
if not exist package.json (
    echo Khong tim thay frontend\package.json
    exit /b 1
)

echo === Cai dependency (neu can) ===
call npm install
if errorlevel 1 exit /b 1

echo.
echo === Build XAMPP: base /hrm/ + API /j1-api ===
set "VITE_BASE_PATH=/hrm/"
set "VITE_API_URL=/j1-api"
call npm run build:deploy
if errorlevel 1 exit /b 1

copy /Y "%ROOT%\deploy\frontend\.htaccess" "%FRONTEND%\dist\.htaccess" >nul

echo.
echo === Dong goi %OUT% ===
if exist "%OUT%" del /f "%OUT%"
powershell -NoProfile -Command "Compress-Archive -Path '%FRONTEND%\dist\*' -DestinationPath '%OUT%' -Force"

echo.
echo Xong. Giai nen vao:
echo   C:\xampp\htdocs\hrm\
echo.
echo Truy cap: http://localhost/hrm/  hoac domain ERP /hrm/
echo API van goi: /j1-api/...
echo.
echo Thu muc dist (copy truc tiep): %FRONTEND%\dist\
endlocal
