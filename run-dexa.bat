@echo off
setlocal
title Run Dexa

set "ROOT=%~dp0"

for %%R in (dexa-backend dexa-audit dexa-hr dexa-employees) do (
    if not exist "%ROOT%%%R\package.json" (
        echo [ERROR] Missing project: %%R
        echo Run install-dexa.bat first.
        echo.
        pause
        exit /b 1
    )
)

for %%R in (dexa-backend dexa-audit dexa-hr dexa-employees) do (
    if not exist "%ROOT%%%R\.env" (
        echo [ERROR] Missing environment file: %%R\.env
        echo Run install-dexa.bat first.
        echo.
        pause
        exit /b 1
    )
)

echo ========================================
echo             Starting Dexa
echo ========================================
echo.

start "Dexa Backend" /D "%ROOT%dexa-backend" cmd /k "npm run start:dev"
start "Dexa Audit" /D "%ROOT%dexa-audit" cmd /k "npm run start:dev"
start "Dexa Employees" /D "%ROOT%dexa-employees" cmd /k "npm run dev -- --host 127.0.0.1 --port 5173 --strictPort"
start "Dexa HR" /D "%ROOT%dexa-hr" cmd /k "npm run dev -- --host 127.0.0.1 --port 5174 --strictPort"

echo.
echo Waiting for services to start...
timeout /t 5 /nobreak >nul

start "" "http://localhost:5173"
start "" "http://localhost:5174"

echo.
echo ========================================
echo Employee app: http://localhost:5173
echo HR app:       http://localhost:5174
echo Backend docs: http://localhost:3000/docs
echo ========================================
echo.
echo Keep all four service windows open.
echo Close their windows to stop the services.
echo.
pause