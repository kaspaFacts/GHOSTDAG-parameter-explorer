@echo off
setlocal enabledelayedexpansion

SET "SCRIPT_DIR=%~dp0"
SET "PORTABLE_DIR=%SCRIPT_DIR%python_313_runtime"
SET "VENV_DIR=%SCRIPT_DIR%.venv"
SET "PYTHON_ZIP=python-3.13.2-embed-amd64.zip"
SET "PYTHON_URL=https://www.python.org/ftp/python/3.13.2/%PYTHON_ZIP%"

:: Step 1: Check if local isolated Python 3.13 exists from a previous run
IF EXIST "%PORTABLE_DIR%\python.exe" (
    SET "SYSTEM_PYTHON=%PORTABLE_DIR%\python.exe"
    GOTO CREATE_VENV
)

:: Step 1 (cont): Check if Python 3.13 is installed system-wide without touching standard Python
py -3.13 --version >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo [OK] Found system Python 3.13.
    SET "SYSTEM_PYTHON=py -3.13"
    GOTO CREATE_VENV
)

:: Step 2: System lacks Python 3.13. Download official isolated Python 3.13 from python.org
echo Python 3.13 was not found. Downloading official isolated Python 3.13...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%SCRIPT_DIR%%PYTHON_ZIP%'"

echo Extracting Python 3.13 runtime...
powershell -Command "Expand-Archive -Path '%SCRIPT_DIR%%PYTHON_ZIP%' -DestinationPath '%PORTABLE_DIR%' -Force"
del "%SCRIPT_DIR%%PYTHON_ZIP%"

:: Enable site-packages support required for venv bootstrapping
powershell -Command "(Get-Content '%PORTABLE_DIR%\python313._pth') -replace '#import site', 'import site' | Set-Content '%PORTABLE_DIR%\python313._pth'"

SET "SYSTEM_PYTHON=%PORTABLE_DIR%\python.exe"

:CREATE_VENV
:: Step 3: Create virtual environment using Python 3.13
IF NOT EXIST "%VENV_DIR%" (
    echo Creating Python 3.13 virtual environment (.venv)...
    %SYSTEM_PYTHON% -m venv "%VENV_DIR%"
    IF %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
)

:: Step 4: Launch the script inside the isolated venv
"%VENV_DIR%\Scripts\python.exe" "%SCRIPT_DIR%ghostdag_calc.py" %*
pause
