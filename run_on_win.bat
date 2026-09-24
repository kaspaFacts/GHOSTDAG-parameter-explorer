@echo off
setlocal enabledelayedexpansion

SET "SCRIPT_DIR=%~dp0"
SET "PORTABLE_DIR=%SCRIPT_DIR%python_313_runtime"
SET "VENV_DIR=%SCRIPT_DIR%.venv"
SET "PYTHON_ZIP=python-3.13.2-embed-amd64.zip"
SET "ZIP_PATH=%SCRIPT_DIR%%PYTHON_ZIP%"
SET "PYTHON_URL=https://www.python.org/ftp/python/3.13.2/%PYTHON_ZIP%"

:: Official SHA-256 checksum for python-3.13.2-embed-amd64.zip
SET "EXPECTED_SHA256=7579fdfa19ec4008ec125b2eddd1f0ae080ae2d80d285fb70a04944439c6b907"

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
    
    :: Download via PowerShell
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%ZIP_PATH%'"
    IF !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Download failed. Please check your network connection.
        pause
        exit /b 1
    )

    :: Verify SHA-256 Integrity
    echo [INFO] Verifying download integrity (SHA-256)...
    powershell -Command "$hash = (Get-FileHash -Path '%ZIP_PATH%' -Algorithm SHA256).Hash.ToLower(); if ($hash -ne '%EXPECTED_SHA256%') { exit 1 }"
    IF !ERRORLEVEL! NEQ 0 (
        echo [ERROR] SHA-256 checksum verification failed! File may be corrupt or tampered with.
        if exist "%ZIP_PATH%" del "%ZIP_PATH%" >nul 2>&1
        pause
        exit /b 1
    )

    :: Extract
    echo [INFO] Checksum verified. Extracting Python runtime...
    powershell -Command "Expand-Archive -Path '%ZIP_PATH%' -DestinationPath '%PORTABLE_DIR%' -Force"
    IF !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Failed to extract runtime archive.
        if exist "%ZIP_PATH%" del "%ZIP_PATH%" >nul 2>&1
        pause
        exit /b 1
    )
    
    if exist "%ZIP_PATH%" del "%ZIP_PATH%"

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
