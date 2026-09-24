#!/usr/bin/env bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PORTABLE_DIR="$SCRIPT_DIR/python_313_runtime"
VENV_DIR="$SCRIPT_DIR/.venv"

# Step 1: Check for existing local isolated Python 3.13 runtime
if [ -f "$PORTABLE_DIR/bin/python3.13" ]; then
    PYTHON_CMD="$PORTABLE_DIR/bin/python3.13"
# Step 1 (cont): Check if python3.13 is natively installed
elif command -v python3.13 &>/dev/null; then
    echo "[OK] Found system Python 3.13."
    PYTHON_CMD="python3.13"
else
    # Step 2: System lacks Python 3.13. Fetch standalone official Python 3.13 binary build
    echo "Python 3.13 not found. Downloading isolated Python 3.13 package..."
    mkdir -p "$PORTABLE_DIR"
    
    # Download standalone Python 3.13 build
    PKG_URL="https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.13.0+20241016-aarch64-apple-darwin-install_only.tar.gz"
    if [[ "$(uname -m)" == "x86_64" ]]; then
        PKG_URL="https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.13.0+20241016-x86_64-apple-darwin-install_only.tar.gz"
    fi

    curl -L "$PKG_URL" \vert{} tar -xz -C "$PORTABLE_DIR" --strip-components=1
    PYTHON_CMD="$PORTABLE_DIR/bin/python3.13"
fi

# Step 3: Create virtual environment using Python 3.13
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python 3.13 virtual environment (.venv)..."
    "$PYTHON_CMD" -m venv "$VENV_DIR"
fi

# Step 4: Launch the tool
"$VENV_DIR/bin/python" "$SCRIPT_DIR/ghostdag_calc.py" "$@"
