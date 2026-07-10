@echo off
setlocal

cd /d "%~dp0"

echo.
echo ============================================================
echo  KB AI Assistant Installer
echo ============================================================
echo  Installation is starting.
echo  Please do not close this window.
echo ============================================================
echo.

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Kobi.ps1"

set ERR=%ERRORLEVEL%

echo.
if "%ERR%"=="0" (
    echo Installation completed successfully.
) else (
    echo Installation failed. ErrorLevel=%ERR%
)

echo.
echo Press any key to close this window.
pause >nul

exit /b %ERR%
