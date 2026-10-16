
@echo off
setlocal
title Dexa Setup

set "ROOT=%~dp0"
set "PARENT=%ROOT%.."

where git >nul 2>&1
if errorlevel 1 (
    echo Git is missing. Install Git for Windows from https://git-scm.com/download/win
    pause
    exit /b 1
)

where node >nul 2>&1
if errorlevel 1 (
    echo Node.js is missing. Install the LTS version from https://nodejs.org/
    pause
    exit /b 1
)

where npm >nul 2>&1
if errorlevel 1 (
    echo npm is missing. Reinstall Node.js LTS.
    pause
    exit /b 1
)

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
    echo.
    echo Installing dependencies for %%R...
    if exist "%PARENT%\%%R\package-lock.json" (
        pushd "%PARENT%\%%R"
        call npm ci
        if errorlevel 1 (
            popd
            goto :fail
        )
        popd
    ) else (
        pushd "%PARENT%\%%R"
        call npm install
        if errorlevel 1 (
            popd
            goto :fail
        )
        popd
    )
)

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
echo Dexa launch commands have been started.
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
if exist "%ROOT%%~2" (
    if exist "%PARENT%\%~1\.env" (
        echo ERROR: %~1 already has a .env file. Refusing to overwrite it.
        exit /b 1
    )
    echo Installing environment for %~1...
    move "%ROOT%%~2" "%PARENT%\%~1\.env" >nul
    if errorlevel 1 exit /b 1
) else (
    if not exist "%PARENT%\%~1\.env" (
        echo ERROR: Missing %~2 and %PARENT%\%~1\.env
        exit /b 1
    )
)
exit /b 0

:fail
echo.
echo SETUP FAILED. Read the error above, fix it, and run START-DEXA.bat again.
pause
exit /b 1
