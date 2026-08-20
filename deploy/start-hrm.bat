@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem === Cau hinh — sua mat khau neu can ===
set "HRM_HOME=C:\hrm"
set "JAR=%HRM_HOME%\hrm-backend-1.0.0.jar"
set "MYSQL_USER=hrm"
set "MYSQL_PASS=MatKhauHrmCuaBan"
set "JWT_SECRET=MinhAn-HRM-2026-ThayDoiChuoiNay-32KyTu"
set "SQLSERVER_PASS=345321@Vn"
set "SERVER_PORT=8086"
set "PUBLIC_ORIGIN=https://erp.benhvienminhan.com"

rem === Tro ly AI (bat buoc de chat AI tren production) ===
set "HR_ASSISTANT_ENABLED=true"
rem Dat GROQ_API_KEY trong bien moi truong may chu (khong commit key vao git)
if not defined GROQ_API_KEY set "GROQ_API_KEY="
set "AI_BASE_URL=https://api.groq.com/openai/v1"
set "HR_ASSISTANT_MODEL=qwen/qwen3.6-27b"
set "HR_ASSISTANT_FALLBACK_MODEL=openai/gpt-oss-120b"
set "OPENAI_HR_ASSISTANT_REASONING_EFFORT=none"

rem === Push FCM (thong bao he thong Android/iOS) ===
set "FCM_PUSH_ENABLED=true"
set "FCM_CREDENTIALS_PATH=C:/secrets/hrm-minh-an-firebase-adminsdk-fbsvc-1ef576f17b.json"

if not exist "%HRM_HOME%" (
    echo Thu muc %HRM_HOME% khong ton tai.
    pause
    exit /b 1
)

if not exist "%JAR%" (
    echo Khong tim thay %JAR%
    pause
    exit /b 1
)

if /I "%FCM_PUSH_ENABLED%"=="true" (
  if not exist "%FCM_CREDENTIALS_PATH%" (
    echo.
    echo [LOI] FCM dang bat nhung khong thay file credentials:
    echo   %FCM_CREDENTIALS_PATH%
    echo Copy file firebase-adminsdk JSON vao dung duong dan tren roi chay lai.
    pause
    exit /b 1
  )
  echo FCM push: BAT — %FCM_CREDENTIALS_PATH%
) else (
  echo FCM push: TAT
)

if not exist "%HRM_HOME%\data\uploads" mkdir "%HRM_HOME%\data\uploads"

cd /d "%HRM_HOME%"

rem Dung instance HRM cu (neu con chay tu lan truoc)
echo Dang kiem tra backend cu...
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='java.exe'\" | Where-Object { $_.CommandLine -like '*hrm-backend*' } | ForEach-Object { Write-Host ('Dung PID ' + $_.ProcessId); Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" 2>nul
for %%P in (8080 %SERVER_PORT%) do (
  for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":%%P" ^| findstr "LISTENING"') do (
      echo Port %%P dang bi PID %%p chiem - dang giai phong...
      taskkill /F /PID %%p >nul 2>&1
  )
)
timeout /t 2 /nobreak >nul

rem Truyen cau hinh qua tham so (tranh loi & trong file .bat)
java -Dfile.encoding=UTF-8 -jar "%JAR%" ^
  --spring.profiles.active=prod ^
  --server.address=0.0.0.0 ^
  --server.port=%SERVER_PORT% ^
  --spring.datasource.url=jdbc:mysql://localhost:3306/minhan_hrm?useSSL=false^&allowPublicKeyRetrieval=true^&characterEncoding=UTF-8^&serverTimezone=Asia/Ho_Chi_Minh ^
  --spring.datasource.username=%MYSQL_USER% ^
  --spring.datasource.password=%MYSQL_PASS% ^
  --minhan.hrm.jwt.secret=%JWT_SECRET% ^
  --minhan.hrm.upload.dir=%HRM_HOME%/data/uploads ^
  --minhan.hrm.cors.allowed-origins=%PUBLIC_ORIGIN% ^
  --minhan.hrm.erp-auth.base-url=%PUBLIC_ORIGIN% ^
  --minhan.hrm.chamcong.enabled=true ^
  --minhan.hrm.chamcong.url=jdbc:sqlserver://localhost:1433;databaseName=chamcong;encrypt=optional;trustServerCertificate=true ^
  --minhan.hrm.chamcong.username=sa ^
  --minhan.hrm.chamcong.password=%SQLSERVER_PASS% ^
  --minhan.hrm.frontend.enabled=true ^
  --minhan.hrm.frontend.dir=%HRM_HOME%\www ^
  --minhan.hrm.assistant.enabled=%HR_ASSISTANT_ENABLED% ^
  --minhan.hrm.assistant.api-key=%GROQ_API_KEY% ^
  --minhan.hrm.assistant.base-url=%AI_BASE_URL% ^
  --minhan.hrm.assistant.model=%HR_ASSISTANT_MODEL% ^
  --minhan.hrm.assistant.fallback-model=%HR_ASSISTANT_FALLBACK_MODEL% ^
  --minhan.hrm.assistant.reasoning-effort=%OPENAI_HR_ASSISTANT_REASONING_EFFORT% ^
  --minhan.hrm.push.enabled=true ^
  --minhan.hrm.push.credentials-path=%FCM_CREDENTIALS_PATH%

echo.
if errorlevel 1 (
    echo Backend KHONG khoi dong duoc. Xem loi o tren.
) else (
    echo Backend da chay OK.
    echo.
    echo  Giao dien (mo tren trinh duyet): %PUBLIC_ORIGIN%/
    echo  Hoac noi bo VM:                  http://localhost:%SERVER_PORT%/
    echo  API (KHONG mo truc tiep):        %PUBLIC_ORIGIN%/j1-api
)
echo Nhan phim bat ky de dong cua so.
pause >nul
endlocal
