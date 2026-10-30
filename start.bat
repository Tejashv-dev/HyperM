@echo off
setlocal
cd /d "%~dp0"

:: Re-launch as administrator (needed for huge pages / MSR tweak = better hashrate)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if not exist xmrig.exe (
    echo xmrig.exe not found in %cd%
    pause
    exit /b 1
)

:: Build the real config with this PC's name as the worker name
powershell -NoProfile -Command "(Get-Content -Raw 'config.json') -replace 'HOSTNAME_PLACEHOLDER','%COMPUTERNAME%' | Set-Content -Encoding ascii 'config.run.json'"

echo Starting miner on %COMPUTERNAME%
xmrig.exe -c config.run.json
pause