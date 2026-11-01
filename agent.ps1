$server = "http://192.168.1.50:9000"   # your collector server
$secret = "g4r4g3-secret"              # must match server.py
$name   = $env:COMPUTERNAME
$dir    = $PSScriptRoot
$headers = @{ "X-Auth" = $secret }

while ($true) {
    # --- report current stats ---
    try {
        $stats = Invoke-RestMethod "http://127.0.0.1:18080/2/summary"
        $body = @{
            name       = $name
            hashrate   = $stats.hashrate.total[0]
            accepted   = $stats.results.shares_good
            rejected   = $stats.results.shares_total - $stats.results.shares_good
        } | ConvertTo-Json
        Invoke-RestMethod -Uri "$server/report" -Method Post -Body $body -ContentType "application/json" -Headers $headers -TimeoutSec 5 | Out-Null
    } catch {}

    # --- check for a pending command ---
    try {
        $resp = Invoke-RestMethod -Uri "$server/poll/$name" -Headers $headers -TimeoutSec 5
        if ($resp.command -eq "stop") {
            Stop-Process -Name xmrig -Force -ErrorAction SilentlyContinue
        }
        elseif ($resp.command -eq "restart") {
            Stop-Process -Name xmrig -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Process -FilePath "wscript.exe" -ArgumentList "`"$dir\run-hidden.vbs`""
        }
    } catch {}

    Start-Sleep -Seconds 30
}