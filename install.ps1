$ErrorActionPreference = 'Stop'
$src  = $PSScriptRoot
$dest = 'C:\GarageMiner'
$user = "$env:USERDOMAIN\$env:USERNAME"

if ((Get-Content -Raw "$src\config.json") -match 'YOUR_PRIMARY_XMR_ADDRESS') {
    throw "config.json still contains YOUR_PRIMARY_XMR_ADDRESS. Put your wallet address in first."
}

Unregister-ScheduledTask -TaskName 'GarageMiner' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'GarageMinerAgent' -Confirm:$false -ErrorAction SilentlyContinue
Get-Process xmrig -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

New-Item -ItemType Directory -Force -Path $dest | Out-Null
try { Add-MpPreference -ExclusionPath $dest }
catch { Write-Warning "Could not add Defender exclusion. Add $dest as an exclusion manually." }

if (Test-Path "$src\xmrig.exe") {
    Copy-Item "$src\xmrig.exe" $dest -Force
    if (Test-Path "$src\WinRing0x64.sys") { Copy-Item "$src\WinRing0x64.sys" $dest -Force }
} else {
    Write-Host "Downloading xmrig from the official GitHub release..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $rel   = Invoke-RestMethod 'https://api.github.com/repos/xmrig/xmrig/releases/latest' -Headers @{ 'User-Agent' = 'garage-miner' }
    $asset = $rel.assets | Where-Object { $_.name -like '*msvc-win64.zip' } | Select-Object -First 1
    if (-not $asset) { throw "Could not find the xmrig Windows download. Put xmrig.exe in this folder and run again." }
    $zip = Join-Path $env:TEMP 'xmrig.zip'
    $tmp = Join-Path $env:TEMP 'xmrig-extract'
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip
    Expand-Archive $zip $tmp -Force
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    Copy-Item "$($inner.FullName)\*" $dest -Force -Exclude 'config.json'
    Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path "$dest\xmrig.exe")) { throw "xmrig.exe is missing from $dest (antivirus may have removed it)." }

# Config + launcher + agent files
Copy-Item "$src\config.json", "$src\start.bat", "$src\run-hidden.vbs", "$src\agent.ps1", "$src\run-agent-hidden.vbs" $dest -Force

$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
$trigger.Delay = 'PT30S'
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
             -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable

$minerAction = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$dest\run-hidden.vbs`"" -WorkingDirectory $dest
Register-ScheduledTask -TaskName 'GarageMiner' -Action $minerAction -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

$agentAction = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$dest\run-agent-hidden.vbs`"" -WorkingDirectory $dest
Register-ScheduledTask -TaskName 'GarageMinerAgent' -Action $agentAction -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

Start-ScheduledTask -TaskName 'GarageMiner'
Start-ScheduledTask -TaskName 'GarageMinerAgent'
Write-Host ""
Write-Host "Done. Miner + agent started, and will auto-start 30 seconds after every login."
Write-Host "Installed to: $dest"