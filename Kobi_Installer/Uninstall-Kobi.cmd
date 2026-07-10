@echo off
setlocal

cd /d "%~dp0"

echo.
echo ============================================================
echo  KB AI Assistant Uninstaller
echo ============================================================
echo  Uninstallation is starting.
echo  Please do not close this window.
echo ============================================================
echo.

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-Kobi.ps1"

set ERR=%ERRORLEVEL%

echo.
if "%ERR%"=="0" (
    echo Uninstallation completed successfully.
) else (
    echo Uninstallation failed. ErrorLevel=%ERR%
)

echo.
echo Press any key to close this window.
pause >nul

exit /b %ERR%
