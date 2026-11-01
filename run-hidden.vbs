Set shell = CreateObject("WScript.Shell")
shell.Run "cmd /c """ & Replace(WScript.ScriptFullName, "run-hidden.vbs", "start.bat") & """", 0, False