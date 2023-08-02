@echo off

PowerShell -NoProfile -Command "&{Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; if (Test-Path -Path 'D:\AutopilotHH' -PathType Container) {& D:\AutopilotHH\Get-AutopilotHardwareHash.ps1} else {Exit 1}}"

if %ERRORLEVEL%==1 echo USB not found!
