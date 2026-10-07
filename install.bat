@echo off
setlocal enabledelayedexpansion
title Maestro AI - Installation Setup
cd /d "%~dp0"

echo ============================================================
echo               Maestro AI - Standalone Setup
echo ============================================================
echo.

:: 1. Check for uv
where uv >nul 2>nul
if %errorlevel% neq 0 (
    if exist "%USERPROFILE%\.local\bin\uv.exe" (
        set "PATH=%USERPROFILE%\.local\bin;!PATH!"
    ) else (
        echo [*] uv was not found in PATH. Installing uv...
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        set "PATH=%USERPROFILE%\.local\bin;%APPDATA%\uv\bin;!PATH!"
    )
)

:: 2. Check for Git
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Git is not installed or not found in PATH.
    echo Please install Git from https://git-scm.com/
    pause
    exit /b 1
)

:: 3. Clone seedvc submodule if missing
if not exist "app\postprocessing\seedvc\__init__.py" (
    echo [*] Cloning seedvc component...
    git clone --depth 1 --branch v1.0.0 https://github.com/Blizaine/maestro-seedvc app\postprocessing\seedvc
) else (
    echo [OK] seedvc component is present.
)

:: 4. Build Web UI if missing
if not exist "ui\dist\index.html" (
    echo [*] Building Web UI - requires Node.js...
    where npm >nul 2>nul
    if %errorlevel% neq 0 (
        echo [WARNING] Node.js/npm not found. Web UI might not build.
    ) else (
        pushd ui
        call npm install
        call npm run build
        popd
    )
) else (
    echo [OK] Web UI is already built.
)

:: 5. Create Python 3.11 virtual environment
echo [*] Checking Python 3.11 virtual environment in app\env...
if not exist "app\env\Scripts\python.exe" (
    echo [*] Creating virtual environment with uv...
    uv venv --python 3.11 app\env
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
) else (
    echo [OK] Python 3.11 environment exists.
)

:: 6. Install requirements.txt
echo.
echo [*] Installing dependencies from app\requirements.txt...
uv pip install -r app\requirements.txt --index-strategy unsafe-best-match --python app\env\Scripts\python.exe
uv pip install hf-xet pip --python app\env\Scripts\python.exe

:: 7. Detect GPU architecture
set "SOL_CAPABLE=0"
for /f "usebackq delims=" %%g in (`powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name" 2^>nul`) do (
    echo Detected GPU: %%g
    echo %%g | findstr /i "40 50 Ada Blackwell" >nul && set "SOL_CAPABLE=1"
)

if "!SOL_CAPABLE!"=="1" (
    echo.
    echo [*] Installing CUDA 13 / PyTorch 2.10 stack for RTX 40 and 50 series...
    uv pip install torch==2.10.0 torchvision==0.25.0 torchaudio==2.10.0 --index-url https://download.pytorch.org/whl/cu130 --force-reinstall --no-deps --python app\env\Scripts\python.exe
    uv pip install xformers==0.0.35 --index-url https://download.pytorch.org/whl/cu130 --force-reinstall --no-deps --python app\env\Scripts\python.exe
    uv pip install triton-windows==3.6.0.post25 --force-reinstall --python app\env\Scripts\python.exe
    uv pip install https://github.com/woct0rdho/SageAttention/releases/download/v2.2.0-windows.post4/sageattention-2.2.0+cu130torch2.9.0andhigher.post4-cp39-abi3-win_amd64.whl --force-reinstall --no-deps --python app\env\Scripts\python.exe
    uv pip install https://github.com/deepbeepmeep/kernels/releases/download/Light2xv/lightx2v_kernel-0.0.2+torch2.10.0-cp311-abi3-win_amd64.whl --force-reinstall --no-deps --python app\env\Scripts\python.exe
    uv pip install https://github.com/nunchaku-ai/nunchaku/releases/download/v1.2.1/nunchaku-1.2.1+cu13.0torch2.10-cp311-cp311-win_amd64.whl --force-reinstall --no-deps --python app\env\Scripts\python.exe
    uv pip install https://github.com/deepbeepmeep/kernels/releases/download/Flash2/flash_attn-2.8.3-cp311-cp311-win_amd64.whl --force-reinstall --no-deps --python app\env\Scripts\python.exe

    echo installed > "app\env\.maestro_sol_runtime_v1.installed" 2>nul
    echo installed > "app\env\.maestro_sol_flash_2_8_3_v1.installed" 2>nul
) else (
    echo.
    echo [*] Installing CUDA 12.8 legacy stack for older GPUs...
    uv pip install torch==2.7.1 torchvision==0.22.1 torchaudio==2.7.1 --index-url https://download.pytorch.org/whl/cu128 --force-reinstall --no-deps --python app\env\Scripts\python.exe
    uv pip install triton-windows==3.3.1.post19 --force-reinstall --python app\env\Scripts\python.exe
    uv pip install https://github.com/woct0rdho/SageAttention/releases/download/v2.2.0-windows/sageattention-2.2.0+cu128torch2.7.1-cp310-cp310-win_amd64.whl --force-reinstall --no-deps --python app\env\Scripts\python.exe
)

:: 8. Install GGUF kernels helper
echo.
echo [*] Checking optional GGUF kernels...
pushd app
call env\Scripts\activate.bat
python scripts\install_gguf_kernels.py
popd

echo.
echo ============================================================
echo [SUCCESS] Installation is complete!
echo You can now run Maestro AI anytime by double-clicking run.bat.
echo ============================================================
pause
