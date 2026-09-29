@echo off
title ResumidorIA V6.2
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ResumidorIA_v6_2.ps1"
echo.
echo ============================================================
echo O ResumidorIA foi encerrado.
echo Pressione qualquer tecla para fechar.
echo ============================================================
pause >nul
