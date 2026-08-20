@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "ROOT=%~dp0.."
set "BACKEND=%ROOT%\backend"
set "OUT=%ROOT%\deploy\hrm-backend-1.0.0.jar"

cd /d "%BACKEND%"
if not exist pom.xml (
    echo Khong tim thay backend\pom.xml
    exit /b 1
)

echo === Build backend (skip tests) ===
call mvn -DskipTests package
if errorlevel 1 exit /b 1

if not exist "target\hrm-backend-1.0.0.jar" (
    echo Khong tim thay target\hrm-backend-1.0.0.jar
    exit /b 1
)

copy /Y "target\hrm-backend-1.0.0.jar" "%OUT%"
echo.
echo Xong: %OUT%
endlocal
