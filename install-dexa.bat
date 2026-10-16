@echo off
setlocal
title Dexa Setup

set "ROOT=%~dp0"
set "PARENT=%ROOT%"
set "ENV_DIR=%ROOT%env"
set "REQUIRED_NODE_MAJOR=24"

echo ========================================
echo             Dexa Setup
echo ========================================
echo.

where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git is not installed or not in PATH.
    echo Install Git for Windows:
    echo https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

for /f "delims=" %%V in ('git --version 2^>nul') do echo [OK] %%V

where node >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Node.js is not installed or not in PATH.
    echo Install Node.js 24 LTS:
    echo https://nodejs.org/en/download
    echo.
    pause
    exit /b 1
)

for /f "delims=" %%V in ('node -p "process.versions.node" 2^>nul') do set "NODE_VERSION=%%V"
for /f "tokens=1 delims=." %%V in ("%NODE_VERSION%") do set "NODE_MAJOR=%%V"

if not defined NODE_VERSION (
    echo [ERROR] Could not determine the Node.js version.
    pause
    exit /b 1
)

echo [INFO] Detected Node.js %NODE_VERSION%

if not "%NODE_MAJOR%"=="%REQUIRED_NODE_MAJOR%" (
    echo.
    echo [ERROR] Dexa requires Node.js %REQUIRED_NODE_MAJOR%.x LTS.
    echo Your installed version is %NODE_VERSION%.
    echo https://nodejs.org/en/download
    echo.
    pause
    exit /b 1
)

where npm >nul 2>&1
if errorlevel 1 (
    echo [ERROR] npm is missing or not in PATH.
    echo Reinstall Node.js %REQUIRED_NODE_MAJOR% LTS.
    echo.
    pause
    exit /b 1
)

for /f "delims=" %%V in ('npm --version 2^>nul') do echo [OK] npm %%V

if not exist "%ENV_DIR%\.env-backend" goto :missing_env
if not exist "%ENV_DIR%\.env-audit" goto :missing_env
if not exist "%ENV_DIR%\.env-hr" goto :missing_env
if not exist "%ENV_DIR%\.env-employees" goto :missing_env

echo.
echo [OK] Prerequisites passed.
echo.

for %%R in (dexa-backend dexa-audit dexa-hr dexa-employees) do (
    call :clone_repo %%R
    if errorlevel 1 goto :fail
)

call :setup_env dexa-backend .env-backend
if errorlevel 1 goto :fail
call :setup_env dexa-audit .env-audit
if errorlevel 1 goto :fail
call :setup_env dexa-hr .env-hr
if errorlevel 1 goto :fail
call :setup_env dexa-employees .env-employees
if errorlevel 1 goto :fail

for %%R in (dexa-backend dexa-audit dexa-hr dexa-employees) do (
    if not exist "%PARENT%\%%R\node_modules\" (
        echo.
        echo Installing dependencies for %%R...
        pushd "%PARENT%\%%R"
        if exist "package-lock.json" (
            call npm ci
        ) else (
            call npm install
        )
        if errorlevel 1 (
            popd
            goto :fail
        )
        popd
    ) else (
        echo Dependencies already installed for %%R.
    )
)

echo.
echo Generating Prisma Client...
pushd "%PARENT%\dexa-backend"
call npx prisma generate
if errorlevel 1 (
    popd
    goto :fail
)
popd

echo.
echo Starting Dexa services...

start "Dexa Backend" /D "%PARENT%\dexa-backend" cmd /k "npm run start:dev"
start "Dexa Audit" /D "%PARENT%\dexa-audit" cmd /k "npm run start:dev"
start "Dexa Employees" /D "%PARENT%\dexa-employees" cmd /k "npm run dev -- --host 127.0.0.1 --port 5173 --strictPort"
start "Dexa HR" /D "%PARENT%\dexa-hr" cmd /k "npm run dev -- --host 127.0.0.1 --port 5174 --strictPort"

echo.
echo Waiting for services to start...
timeout /t 5 /nobreak >nul

start "" "http://localhost:5173"
start "" "http://localhost:5174"

echo.
echo ========================================
echo Dexa launch commands have been started.
echo ========================================
echo Employee app: http://localhost:5173
echo HR app:       http://localhost:5174
echo Backend docs: http://localhost:3000/docs
echo.
echo Keep the service windows open while using Dexa.
pause
exit /b 0

:clone_repo
if exist "%PARENT%\%~1\.git\" (
    echo Reusing %~1
    exit /b 0
)

if exist "%PARENT%\%~1\" (
    echo ERROR: %PARENT%\%~1 exists but is not a Git repository.
    exit /b 1
)

echo Cloning %~1...
git clone "https://github.com/AdriAntoriV2/%~1.git" "%PARENT%\%~1"
if errorlevel 1 exit /b 1
exit /b 0

:setup_env
if not exist "%PARENT%\%~1\.env" (
    echo Copying environment for %~1...
    copy /Y "%ENV_DIR%\%~2" "%PARENT%\%~1\.env" >nul
    if errorlevel 1 exit /b 1
) else (
    echo Keeping existing environment for %~1.
)
exit /b 0

:missing_env
echo.
echo [ERROR] One or more environment files are missing from:
echo %ENV_DIR%
echo.
echo Required files:
echo .env-backend
echo .env-audit
echo .env-hr
echo .env-employees
echo.
pause
exit /b 1

:fail
echo.
echo SETUP FAILED. Read the error above, fix it, and run install-dexa.bat again.
pause
exit /b 1