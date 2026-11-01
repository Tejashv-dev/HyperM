# Triggered remotely via the dashboard's "Purge PC" button + admin password.
# agent.ps1 copies this file to %TEMP% and runs it from there before exiting,
# so it can safely delete C:\HyperM (which would otherwise still be in use
# by the agent process that launched it).

$ErrorActionPreference = 'SilentlyContinue'
$dest = 'C:\HyperM'

Start-Sleep -Seconds 2   # give the parent agent.ps1 a moment to exit and release the folder

# 1. Stop the miner
Stop-Process -Name xmrig -Force

# 2. Remove scheduled tasks (current + old pre-rename names)
Unregister-ScheduledTask -TaskName 'HyperM' -Confirm:$false
Unregister-ScheduledTask -TaskName 'HyperMAgent' -Confirm:$false
Unregister-ScheduledTask -TaskName 'GarageMiner' -Confirm:$false
Unregister-ScheduledTask -TaskName 'GarageMinerAgent' -Confirm:$false

# 3. Remove the Windows Defender exclusion
try { Remove-MpPreference -ExclusionPath $dest } catch {}
try { Remove-MpPreference -ExclusionPath 'C:\GarageMiner' } catch {}

# 4. Delete the install folder entirely
Remove-Item $dest -Recurse -Force
Remove-Item 'C:\GarageMiner' -Recurse -Force -ErrorAction SilentlyContinue

# 5. Self-delete this temp copy so nothing lingers
Start-Sleep -Seconds 1
Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue