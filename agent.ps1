# Fill these in before distributing to each PC
$server = "https://hypermb.onrender.com"   # your Render URL, no trailing slash
$secret = "hyperminer974562137654"         # must match MINER_SECRET on Render

$name       = $env:COMPUTERNAME
$dir        = $PSScriptRoot
$configPath = Join-Path $dir "config.json"
$headers    = @{ "X-Auth" = $secret }

function Get-CurrentConfigValues {
    try {
        $cfg = Get-Content -Raw $configPath | ConvertFrom-Json
        return @{
            max_threads_hint = $cfg.cpu.'max-threads-hint'
            pause_on_active  = $cfg.'pause-on-active'
        }
    } catch {
        return @{ max_threads_hint = $null; pause_on_active = $null }
    }
}

function Apply-Config($newCfg) {
    try {
        $cfg = Get-Content -Raw $configPath | ConvertFrom-Json

        if ($null -ne $newCfg.max_threads_hint) {
            $cfg.cpu.'max-threads-hint' = [int]$newCfg.max_threads_hint
        }
        if ($null -ne $newCfg.pause_on_active) {
            $cfg | Add-Member -NotePropertyName 'pause-on-active' -NotePropertyValue ([int]$newCfg.pause_on_active) -Force
        }

        $cfg | ConvertTo-Json -Depth 10 | Set-Content -Encoding ascii $configPath

        # Apply by restarting the miner (config.run.json is rebuilt by start.bat on launch)
        Stop-Process -Name xmrig -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process -FilePath "wscript.exe" -ArgumentList "`"$dir\run-hidden.vbs`""
    } catch {}
}

while ($true) {
    # --- report current stats + currently-applied config ---
    try {
        $stats   = Invoke-RestMethod "http://127.0.0.1:18080/2/summary" -TimeoutSec 5
        $current = Get-CurrentConfigValues
        $body = @{
            name             = $name
            hashrate         = $stats.hashrate.total[0]
            accepted         = $stats.results.shares_good
            rejected         = $stats.results.shares_total - $stats.results.shares_good
            max_threads_hint = $current.max_threads_hint
            pause_on_active  = $current.pause_on_active
        } | ConvertTo-Json
        Invoke-RestMethod -Uri "$server/report" -Method Post -Body $body -ContentType "application/json" -Headers $headers -TimeoutSec 10 | Out-Null
    } catch {}

    # --- check for a pending command or config change ---
    try {
        $resp = Invoke-RestMethod -Uri "$server/poll/$name" -Headers $headers -TimeoutSec 10

        if ($resp.command -eq "stop") {
            Stop-Process -Name xmrig -Force -ErrorAction SilentlyContinue
        }
        elseif ($resp.command -eq "restart") {
            Stop-Process -Name xmrig -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Process -FilePath "wscript.exe" -ArgumentList "`"$dir\run-hidden.vbs`""
        }

        if ($null -ne $resp.config) {
            Apply-Config $resp.config
        }
    } catch {}

    Start-Sleep -Seconds 30
}