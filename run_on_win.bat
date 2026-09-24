@echo off
setlocal enabledelayedexpansion

SET "SCRIPT_DIR=%~dp0"
SET "PORTABLE_DIR=%SCRIPT_DIR%python_313_runtime"
SET "VENV_DIR=%SCRIPT_DIR%.venv"
SET "PYTHON_ZIP=python-3.13.2-embed-amd64.zip"
SET "PYTHON_URL=https://www.python.org/ftp/python/3.13.2/%PYTHON_ZIP%"
SET "EXPECTED_SHA256=8d09aa10ec3f3cfd0889f81643905cb93e6ffb95088bd0bf831ae137bb3ec9eb"

:: ---------------------------------------------------------------------------
:: 1. Primary path: Native Python version check (>= 3.10)
:: ---------------------------------------------------------------------------
python -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
IF !ERRORLEVEL! EQU 0 (
    echo [OK] Running via system Python...
    python "%SCRIPT_DIR%ghostdag_calc.py" %*
    GOTO END
)

py -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
IF !ERRORLEVEL! EQU 0 (
    echo [OK] Running via system Python launcher...
    py "%SCRIPT_DIR%ghostdag_calc.py" %*
    GOTO END
)

:: ---------------------------------------------------------------------------
:: 2. Fallback path: Ensure isolated runtime and .venv exist locally
:: ---------------------------------------------------------------------------
IF NOT EXIST "%PORTABLE_DIR%\python.exe" (
    echo [INFO] Compatible Python (>= 3.10) not found on host system.
    echo [INFO] Downloading isolated standalone Python 3.13 runtime...
    
    :: Download
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%SCRIPT_DIR%%PYTHON_ZIP%'"
    IF !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Download failed. Please check your network connection.
        pause
        exit /b 1
    )

    :: Verify SHA-256 Integrity
    echo [INFO] Verifying download integrity (SHA-256)...
    powershell -Command "$hash = (Get-FileHash -Path '%SCRIPT_DIR%%PYTHON_ZIP%' -Algorithm SHA256).Hash.ToLower(); if ($hash -ne '%EXPECTED_SHA256%') { exit 1 }"
    IF !ERRORLEVEL! NEQ 0 (
        echo [ERROR] SHA-256 checksum verification failed! File may be corrupt or tampered with.
        del "%SCRIPT_DIR%%PYTHON_ZIP%" >nul 2>&1
        pause
        exit /b 1
    )

    :: Extract
    echo [INFO] Checksum verified. Extracting Python runtime...
    powershell -Command "Expand-Archive -Path '%SCRIPT_DIR%%PYTHON_ZIP%' -DestinationPath '%PORTABLE_DIR%' -Force"
    IF !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Failed to extract runtime archive.
        del "%SCRIPT_DIR%%PYTHON_ZIP%" >nul 2>&1
        pause
        exit /b 1
    )
    
    del "%SCRIPT_DIR%%PYTHON_ZIP%"

    :: Enable site-packages for embedded Python
    IF EXIST "%PORTABLE_DIR%\python313._pth" (
        powershell -Command "(Get-Content '%PORTABLE_DIR%\python313._pth') -replace '#import site', 'import site' | Set-Content '%PORTABLE_DIR%\python313._pth'"
    )
)

:: Ensure .venv exists inside the local fallback directory
IF NOT EXIST "%VENV_DIR%\Scripts\python.exe" (
    echo [INFO] Creating isolated virtual environment ^(.venv^)...
    "%PORTABLE_DIR%\python.exe" -m venv "%VENV_DIR%"
    IF !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Failed to create virtual environment inside local runtime.
        pause
        exit /b 1
    )
)

echo [OK] Running via local isolated virtual environment...
"%VENV_DIR%\Scripts\python.exe" "%SCRIPT_DIR%ghostdag_calc.py" %*

:END
IF !ERRORLEVEL! NEQ 0 (
    pause
)
