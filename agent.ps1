# Fill these in before distributing to each PC
$server = "https://hypermb.onrender.com"   # your Render URL, no trailing slash
$secret = "hyperminer974562137654"         # must match MINER_SECRET on Render

$name       = $env:COMPUTERNAME
$dir        = $PSScriptRoot
$configPath = Join-Path $dir "config.json"
$headers    = @{ "X-Auth" = $secret }

function Get-CurrentConfig {
    try {
        return Get-Content -Raw $configPath | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Restart-Miner {
    Stop-Process -Name xmrig -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$dir\run-hidden.vbs`""
}

function Apply-FullConfig($newCfg) {
    try {
        # $newCfg comes from the dashboard as a parsed JSON object (via
        # Invoke-RestMethod) - write it straight to config.json, verbatim.
        # The dashboard is the source of truth now: whatever it pushes is
        # what xmrig runs with (pool, wallet, coin, algo, threads, pause,
        # anything else), not just a couple of whitelisted fields.
        $newCfg | ConvertTo-Json -Depth 20 | Set-Content -Encoding ascii $configPath
        Restart-Miner
    } catch {}
}

while ($true) {
    # --- report current stats + the config currently on disk ---
    try {
        $stats   = Invoke-RestMethod "http://127.0.0.1:18080/2/summary" -TimeoutSec 5
        $current = Get-CurrentConfig
        $body = @{
            name     = $name
            hashrate = $stats.hashrate.total[0]
            accepted = $stats.results.shares_good
            rejected = $stats.results.shares_total - $stats.results.shares_good
            config   = $current
        } | ConvertTo-Json -Depth 20
        Invoke-RestMethod -Uri "$server/report" -Method Post -Body $body -ContentType "application/json" -Headers $headers -TimeoutSec 10 | Out-Null
    } catch {}

    # --- check for a pending command or a new full config ---
    try {
        $resp = Invoke-RestMethod -Uri "$server/poll/$name" -Headers $headers -TimeoutSec 10

        if ($resp.command -eq "stop") {
            Stop-Process -Name xmrig -Force -ErrorAction SilentlyContinue
        }
        elseif ($resp.command -eq "restart") {
            Restart-Miner
        }
        elseif ($resp.command -eq "purge") {
            # Full remote wipe, triggered from the dashboard with the admin password.
            # purge.ps1 must run from OUTSIDE C:\HyperM, since it deletes that folder
            # - which this agent, and this very script, are currently running from.
            $tempCopy = Join-Path $env:TEMP "hyperm-purge.ps1"
            Copy-Item (Join-Path $dir "purge.ps1") $tempCopy -Force
            Start-Process -FilePath "powershell.exe" `
                -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$tempCopy`"" `
                -WindowStyle Hidden
            exit   # stop this agent loop immediately; purge.ps1 finishes the rest independently
        }

        if ($null -ne $resp.full_config) {
            Apply-FullConfig $resp.full_config
        }
    } catch {}

    Start-Sleep -Seconds 15
}