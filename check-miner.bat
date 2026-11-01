@echo off
tasklist /fi "imagename eq xmrig.exe" | find /i "xmrig.exe" >nul
if %errorlevel%==0 (
    echo Miner is running.
) else (
    echo Miner is NOT running.
)
pause