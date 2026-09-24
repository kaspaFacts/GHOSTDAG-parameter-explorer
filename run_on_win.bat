@echo off

:: ---------------------------------------------------------------------------
:: GHOSTDAG Parameter Explorer - Windows Launcher
:: ---------------------------------------------------------------------------

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

set "PORTABLE_DIR=%SCRIPT_DIR%python_313_runtime"
set "VENV_DIR=%SCRIPT_DIR%.venv"
set "PYTHON_ZIP=python-3.13.2-embed-amd64.zip"
set "ZIP_PATH=%SCRIPT_DIR%%PYTHON_ZIP%"
set "PYTHON_URL=https://www.python.org/ftp/python/3.13.2/%PYTHON_ZIP%"

:: Official SHA-256 for python-3.13.2-embed-amd64.zip
set "EXPECTED_SHA256=7579fdfa19ec4008ec125b2eddd1f0ae080ae2d80d285fb70a04944439c6b907"

:: ---------------------------------------------------------------------------
:: 1. Primary path: Native Python version check (>= 3.10)
:: ---------------------------------------------------------------------------
python -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Running via system Python...
    python "%SCRIPT_DIR%ghostdag_calc.py" %*
    goto END
)

py -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Running via system Python launcher...
    py "%SCRIPT_DIR%ghostdag_calc.py" %*
    goto END
)

:: ---------------------------------------------------------------------------
:: 2. Fallback path: Isolated local runtime and .venv in project directory
:: ---------------------------------------------------------------------------
if not exist "%PORTABLE_DIR%\python.exe" (
    echo [INFO] Compatible Python ^(^>= 3.10^) not found on host system.
    echo [INFO] Downloading isolated standalone Python 3.13 runtime...

    :: Download via PowerShell with fail-fast HTTP behavior
    powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%ZIP_PATH%' -ErrorAction Stop"
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Download failed. Check your network connection or proxy settings.
        if exist "%ZIP_PATH%" del "%ZIP_PATH%" >nul 2>&1
        exit /b 1
    )

    :: Verify SHA-256 Integrity (fail-closed)
    echo [INFO] Verifying download integrity ^(SHA-256^)...
    powershell -NoProfile -Command "$hash = (Get-FileHash -Path '%ZIP_PATH%' -Algorithm SHA256 -ErrorAction Stop).Hash.ToLower(); if ($hash -ne '%EXPECTED_SHA256%') { exit 1 }"
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] SHA-256 checksum verification failed or Get-FileHash failed!
        echo [ERROR] The downloaded archive may be corrupted or tampered with.
        if exist "%ZIP_PATH%" del "%ZIP_PATH%" >nul 2>&1
        exit /b 1
    )

    :: Extract runtime archive
    echo [INFO] Checksum verified. Extracting Python runtime...
    powershell -NoProfile -Command "Expand-Archive -Path '%ZIP_PATH%' -DestinationPath '%PORTABLE_DIR%' -Force -ErrorAction Stop"
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to extract runtime archive.
        if exist "%ZIP_PATH%" del "%ZIP_PATH%" >nul 2>&1
        exit /b 1
    )

    if exist "%ZIP_PATH%" del "%ZIP_PATH%" >nul 2>&1

    :: Enable site-packages for embedded Python runtime
    if exist "%PORTABLE_DIR%\python313._pth" (
        powershell -NoProfile -Command "(Get-Content '%PORTABLE_DIR%\python313._pth') -replace '#import site', 'import site' | Set-Content '%PORTABLE_DIR%\python313._pth' -ErrorAction Stop"
        if %ERRORLEVEL% neq 0 (
            echo [ERROR] Failed to configure embedded Python import settings.
            exit /b 1
        )
    )
)

:: Ensure local .venv exists inside the project folder
if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo [INFO] Creating isolated virtual environment ^(.venv^)...
    "%PORTABLE_DIR%\python.exe" -m venv "%VENV_DIR%"
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to create virtual environment inside project folder.
        exit /b 1
    )
)

echo [OK] Running via local isolated virtual environment...
"%VENV_DIR%\Scripts\python.exe" "%SCRIPT_DIR%ghostdag_calc.py" %*

:END
