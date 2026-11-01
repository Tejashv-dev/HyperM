$ErrorActionPreference = 'SilentlyContinue'
$dest = 'C:\HyperM'

Write-Host "=== HyperM full cleanup ==="

# 1. Stop the miner
Write-Host "Stopping xmrig..."
Stop-Process -Name xmrig -Force

# 2. Remove both scheduled tasks (current names)
Write-Host "Removing scheduled tasks..."
Unregister-ScheduledTask -TaskName 'HyperM' -Confirm:$false
Unregister-ScheduledTask -TaskName 'HyperMAgent' -Confirm:$false

# Also clean up the old pre-rename task names, in case this PC was never
# migrated off the original "GarageMiner" install.
Unregister-ScheduledTask -TaskName 'GarageMiner' -Confirm:$false
Unregister-ScheduledTask -TaskName 'GarageMinerAgent' -Confirm:$false

# 3. Remove the Windows Defender exclusion
Write-Host "Removing Defender exclusion..."
try { Remove-MpPreference -ExclusionPath $dest } catch {}
try { Remove-MpPreference -ExclusionPath 'C:\GarageMiner' } catch {}  # old path, if present

# 4. Delete the install folder (xmrig, configs, scripts - everything)
Write-Host "Deleting $dest ..."
Remove-Item $dest -Recurse -Force
Remove-Item 'C:\GarageMiner' -Recurse -Force -ErrorAction SilentlyContinue  # old path, if present

# 5. Confirm nothing is left behind
$stillRunning = Get-Process xmrig -ErrorAction SilentlyContinue
$stillHasTasks = @(Get-ScheduledTask -TaskName 'HyperM','HyperMAgent' -ErrorAction SilentlyContinue).Count -gt 0
$stillHasFolder = Test-Path $dest

Write-Host ""
Write-Host "=== Done ==="
Write-Host ("xmrig running:        " + ($(if ($stillRunning) { "STILL RUNNING - check manually" } else { "stopped" })))
Write-Host ("Scheduled tasks left:  " + ($(if ($stillHasTasks) { "SOME REMAIN - check Task Scheduler" } else { "none" })))
Write-Host ("Install folder:       " + ($(if ($stillHasFolder) { "STILL PRESENT - check manually" } else { "removed" })))
Write-Host ""
Write-Host "This PC has been fully restored. Note: this script does NOT touch"
Write-Host "the dashboard - if this PC is still shown there, it will simply"
Write-Host "stop reporting and show offline after ~3 minutes."