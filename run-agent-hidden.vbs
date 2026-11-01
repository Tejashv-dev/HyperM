Set shell = CreateObject("WScript.Shell")
shell.Run "powershell -NoProfile -ExecutionPolicy Bypass -File """ & Replace(WScript.ScriptFullName, "run-agent-hidden.vbs", "agent.ps1") & """", 0, False