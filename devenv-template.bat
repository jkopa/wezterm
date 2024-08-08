@echo off

rem call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -startdir=none -arch=x64 -host_arch=x64
rem call "C:\Program Files\Git\bin\bash.exe" -i -l

call powershell.exe -NoExit -Command "&{Import-Module """C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"""; Enter-VsDevShell d5cfe25b -SkipAutomaticLocation -DevCmdArguments """-arch=x64 -host_arch=x64"""}"
