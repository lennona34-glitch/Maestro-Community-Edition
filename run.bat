@echo off
setlocal enabledelayedexpansion
title Maestro AI
cd /d "%~dp0"

echo ============================================================
echo                     Starting Maestro AI
echo ============================================================
echo.

:: 1. Ensure uv is accessible if in user folder
where uv >nul 2>nul
if %errorlevel% neq 0 (
    if exist "%USERPROFILE%\.local\bin\uv.exe" (
        set "PATH=%USERPROFILE%\.local\bin;%PATH%"
    )
)

:: 2. Check if virtual environment and PyTorch are installed
if not exist "app\env\Scripts\python.exe" goto :NEED_INSTALL
"%~dp0app\env\Scripts\python.exe" -c "import torch" >nul 2>nul
if %errorlevel% neq 0 goto :NEED_INSTALL
goto :READY

:NEED_INSTALL
echo [-] Python dependencies are not yet installed in app\env.
echo.
set /p choice="Would you like to run the installation setup now? (Y/N): "
if /i "!choice!"=="Y" (
    call "%~dp0install.bat"
    if not exist "app\env\Scripts\python.exe" (
        echo [ERROR] Installation did not complete.
        pause
        exit /b 1
    )
    "%~dp0app\env\Scripts\python.exe" -c "import torch" >nul 2>nul
    if %errorlevel% neq 0 (
        echo [ERROR] PyTorch installation check failed. Please check install.bat.
        pause
        exit /b 1
    )
) else (
    echo [INFO] You can double-click install.bat whenever you are ready.
    pause
    exit /b 1
)

:READY
:: 3. Check if UI is built
if not exist "ui\dist\index.html" (
    echo [-] Web UI is not compiled in ui\dist. Compiling Web UI now...
    pushd ui
    call npm install
    call npm run build
    popd
)

:: 4. Server configuration
if "%SERVER_PORT%"=="" set SERVER_PORT=7860
if "%SERVER_NAME%"=="" set SERVER_NAME=127.0.0.1

echo [*] Local Web UI will be at: http://127.0.0.1:%SERVER_PORT%/
echo [*] Press Ctrl+C in this console window to stop Maestro AI.
echo.

:: Automatically open default browser after a 5 second delay to let server start
start "" cmd /c "timeout /t 5 >nul && start http://127.0.0.1:%SERVER_PORT%/"

:: 5. Proxy configuration check
if exist "%~dp0proxy_config.txt" (
    findstr /i "^ENABLE_PROXY=true" "%~dp0proxy_config.txt" >nul 2>nul
    if !errorlevel! equ 0 (
        echo [*] NordVPN Proxy routing enabled in proxy_config.txt
    )
)

:: 6. Launch backend
cd /d "%~dp0app"
call env\Scripts\activate.bat
set "PYTHONPATH=%~dp0app;%PYTHONPATH%"
python launch.py

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Maestro AI exited with error code %errorlevel%.
    pause
)
