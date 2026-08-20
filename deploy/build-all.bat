@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "DEPLOY=%~dp0"

echo === 1/2 Backend ===
call "%DEPLOY%build-backend.bat"
if errorlevel 1 exit /b 1

echo.
echo === 2/2 Frontend ===
call "%DEPLOY%build-frontend.bat"
if errorlevel 1 exit /b 1

echo.
echo === Dong goi deploy bundle ===
set "BUNDLE=%DEPLOY%hrm-deploy-bundle.zip"
if exist "%BUNDLE%" del /f "%BUNDLE%"
powershell -NoProfile -Command ^
  "Compress-Archive -Path @('%DEPLOY%hrm-backend-1.0.0.jar','%DEPLOY%hrm-frontend-dist.zip','%DEPLOY%start-hrm.bat','%DEPLOY%install-frontend-on-vm.ps1') -DestinationPath '%BUNDLE%' -Force"

echo.
echo Xong. Copy len server:
echo   %BUNDLE%
echo Hoac copy rieng:
echo   %DEPLOY%hrm-backend-1.0.0.jar  -^> C:\hrm\
echo   %DEPLOY%hrm-frontend-dist.zip  -^> C:\hrm\
echo   %DEPLOY%start-hrm.bat          -^> C:\hrm\
endlocal
