@echo off
setlocal
set "OPSEC_SCRIPT=%~dp0opsec.ps1"
if not exist "%OPSEC_SCRIPT%" (
  echo opsec.ps1 was not found next to this file. Unzip the whole folder first.
  pause
  exit /b 1
)
echo OPSEC needs administrator rights. Windows will ask you to allow it.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File',('\"' + $env:OPSEC_SCRIPT + '\"')"
endlocal
