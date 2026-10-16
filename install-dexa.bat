
@echo off
setlocal EnableExtensions
title Dexa Setup

fltmc >nul 2>&1
if errorlevel 1 (
    echo Requesting administrator permission...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
    exit /b
)

set "ROOT=%~dp0"
set "PARENT=%ROOT%"
set "ENV_DIR=%ROOT%env"
set "REQUIRED_NODE_MAJOR=24"
set "NODE_INSTALL_VERSION=24.22.0"

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

if not exist "%ENV_DIR%\.env-backend" goto :missing_env
if not exist "%ENV_DIR%\.env-audit" goto :missing_env
if not exist "%ENV_DIR%\.env-hr" goto :missing_env
if not exist "%ENV_DIR%\.env-employees" goto :missing_env

call :ensure_node
if errorlevel 1 goto :fail

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

:ensure_node
set "NVM_EXE="
set "NODE_VERSION="
set "NODE_MAJOR="
set "NPM_VERSION="

where nvm >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%N in ('where nvm 2^>nul') do if not defined NVM_EXE set "NVM_EXE=%%N"
)

if not defined NVM_EXE if defined NVM_HOME if exist "%NVM_HOME%\nvm.exe" set "NVM_EXE=%NVM_HOME%\nvm.exe"

if defined NVM_EXE (
    echo [INFO] NVM for Windows detected.
    call :check_node
    if not errorlevel 1 exit /b 0
    goto :ensure_node_nvm
)

call :check_node
if not errorlevel 1 exit /b 0

goto :install_node_msi

:check_node
set "NODE_VERSION="
set "NODE_MAJOR="
set "NPM_VERSION="

where node >nul 2>&1
if errorlevel 1 exit /b 1

for /f "delims=" %%V in ('node -p "process.versions.node" 2^>nul') do set "NODE_VERSION=%%V"
if not defined NODE_VERSION exit /b 1

for /f "tokens=1 delims=." %%V in ("%NODE_VERSION%") do set "NODE_MAJOR=%%V"
if not "%NODE_MAJOR%"=="%REQUIRED_NODE_MAJOR%" exit /b 1

where npm >nul 2>&1
if errorlevel 1 exit /b 1

for /f "delims=" %%V in ('npm --version 2^>nul') do set "NPM_VERSION=%%V"
if not defined NPM_VERSION exit /b 1

echo [OK] Node.js %NODE_VERSION%
echo [OK] npm %NPM_VERSION%
exit /b 0

:ensure_node_nvm
echo.
echo [INFO] NVM for Windows detected.
echo [INFO] Activating Node.js %NODE_INSTALL_VERSION%...

call "%NVM_EXE%" use %NODE_INSTALL_VERSION%
if errorlevel 1 (
    echo [INFO] Node.js %NODE_INSTALL_VERSION% is not active or not installed.
    echo [INFO] Installing it through NVM...
    call "%NVM_EXE%" install %NODE_INSTALL_VERSION% 64
    if errorlevel 1 (
        echo [ERROR] NVM could not install Node.js %NODE_INSTALL_VERSION%.
        exit /b 1
    )
    call "%NVM_EXE%" use %NODE_INSTALL_VERSION%
    if errorlevel 1 (
        echo [ERROR] NVM could not activate Node.js %NODE_INSTALL_VERSION%.
        exit /b 1
    )
)

if defined NVM_SYMLINK set "PATH=%NVM_SYMLINK%;%PATH%"
if defined NVM_HOME set "PATH=%NVM_HOME%;%PATH%"

call :check_node
if not errorlevel 1 exit /b 0

echo [ERROR] Node.js 24 and npm could not be verified after NVM activation.
exit /b 1

:install_node_msi
echo.
echo [INFO] Node.js 24.x is not available.
echo [INFO] Downloading Node.js %NODE_INSTALL_VERSION% LTS...

set "NODE_ARCH=x64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "NODE_ARCH=arm64"
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "NODE_ARCH=arm64"

set "NODE_MSI=%TEMP%\node-v%NODE_INSTALL_VERSION%-%NODE_ARCH%.msi"
set "NODE_URL=https://nodejs.org/dist/v%NODE_INSTALL_VERSION%/node-v%NODE_INSTALL_VERSION%-%NODE_ARCH%.msi"

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri '%NODE_URL%' -OutFile '%NODE_MSI%' -UseBasicParsing; exit 0 } catch { Write-Host $_; exit 1 }"
if errorlevel 1 (
    echo [ERROR] Failed to download the Node.js installer.
    echo Check your internet connection and the official download URL:
    echo %NODE_URL%
    exit /b 1
)

echo [INFO] Installing Node.js silently...
msiexec.exe /i "%NODE_MSI%" /quiet /norestart
set "MSI_EXIT_CODE=%ERRORLEVEL%"

if not "%MSI_EXIT_CODE%"=="0" if not "%MSI_EXIT_CODE%"=="3010" (
    echo [ERROR] Node.js installation failed with code %MSI_EXIT_CODE%.
    echo You may need administrator permission.
    del "%NODE_MSI%" >nul 2>&1
    exit /b 1
)

del "%NODE_MSI%" >nul 2>&1

if exist "%ProgramFiles%\nodejs\node.exe" set "PATH=%ProgramFiles%\nodejs;%PATH%"
if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "PATH=%ProgramFiles(x86)%\nodejs;%PATH%"

set "NODE_VERSION="
set "NODE_MAJOR="
set "NPM_VERSION="

where node >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is not available in PATH after installation.
    exit /b 1
)

for /f "delims=" %%V in ('node -p "process.versions.node" 2^>nul') do set "NODE_VERSION=%%V"
for /f "tokens=1 delims=." %%V in ("%NODE_VERSION%") do set "NODE_MAJOR=%%V"

if not "%NODE_MAJOR%"=="%REQUIRED_NODE_MAJOR%" (
    echo [ERROR] Expected Node.js 24.x but detected %NODE_VERSION%.
    exit /b 1
)

where npm >nul 2>&1
if errorlevel 1 (
    echo [ERROR] npm is not available in PATH after installation.
    exit /b 1
)

for /f "delims=" %%V in ('npm --version 2^>nul') do set "NPM_VERSION=%%V"
if not defined NPM_VERSION (
    echo [ERROR] npm could not be executed.
    exit /b 1
)

echo [OK] Node.js %NODE_VERSION%
echo [OK] npm %NPM_VERSION%
exit /b 0

:clone_repo
if exist "%PARENT%\%~1\.git\" (
    echo Reusing %~1
    exit /b 0
)

if exist "%PARENT%\%~1\" (
    echo [ERROR] "%PARENT%\%~1" exists but is not a Git repository.
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
