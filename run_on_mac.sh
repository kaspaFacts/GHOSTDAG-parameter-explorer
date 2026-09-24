#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# GHOSTDAG Parameter Explorer - macOS
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

PORTABLE_DIR="$SCRIPT_DIR/python_313_runtime"
VENV_DIR="$SCRIPT_DIR/.venv"
PYTHON_TAR="python-3.13.2-macos-apple-silicon.tar.gz"
TAR_PATH="$SCRIPT_DIR/$PYTHON_TAR"
PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/20250212/cpython-3.13.2+20250212-aarch64-apple-darwin-install_only.tar.gz"

# Official SHA-256 for standalone Python build
EXPECTED_SHA256="4d1a3c7f99ee307d06a9db3f56bc38bc602b9f6266adcae3c50965022137976e"

# ---------------------------------------------------------------------------
# 1. Primary path: Native Python version check (>= 3.10)
# ---------------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >/dev/null 2>&1; then
        echo "[OK] Running via system Python 3..."
        exec python3 "$SCRIPT_DIR/ghostdag_calc.py" "$@"
    fi
fi

# ---------------------------------------------------------------------------
# 2. Fallback path: Ensure isolated runtime and .venv exist locally
# ---------------------------------------------------------------------------
if [ ! -f "$PORTABLE_DIR/bin/python3" ]; then
    echo "[INFO] Compatible Python (>= 3.10) not found on host system."
    echo "[INFO] Downloading isolated standalone Python 3.13 runtime..."

    # Download via curl (-f fail fast on HTTP errors) or wget
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "$PYTHON_URL" -o "$TAR_PATH"; then
            echo "[ERROR] Download failed via curl."
            rm -f "$TAR_PATH"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q "$PYTHON_URL" -O "$TAR_PATH"; then
            echo "[ERROR] Download failed via wget."
            rm -f "$TAR_PATH"
            exit 1
        fi
    else
        echo "[ERROR] Neither curl nor wget is available to download Python runtime."
        exit 1
    fi

    # Verify SHA-256 Integrity
    echo "[INFO] Verifying download integrity (SHA-256)..."
    if command -v shasum >/dev/null 2>&1; then
        COMPUTED_HASH=$(shasum -a 256 "$TAR_PATH" | awk '{print $1}')
    elif command -v sha256sum >/dev/null 2>&1; then
        COMPUTED_HASH=$(sha256sum "$TAR_PATH" | awk '{print $1}')
    else
        echo "[ERROR] System lacks 'shasum' or 'sha256sum' to verify download integrity."
        rm -f "$TAR_PATH"
        exit 1
    fi

    if [ "$COMPUTED_HASH" != "$EXPECTED_SHA256" ]; then
        echo "[ERROR] SHA-256 checksum verification failed! File may be corrupt or tampered with."
        rm -f "$TAR_PATH"
        exit 1
    fi

    # Extract
    echo "[INFO] Checksum verified. Extracting Python runtime..."
    mkdir -p "$PORTABLE_DIR"
    if ! tar -xzf "$TAR_PATH" -C "$PORTABLE_DIR" --strip-components=1; then
        echo "[ERROR] Failed to extract runtime archive."
        rm -f "$TAR_PATH"
        exit 1
    fi

    rm -f "$TAR_PATH"
fi

# Ensure .venv exists inside the local fallback directory
if [ ! -f "$VENV_DIR/bin/python" ]; then
    echo "[INFO] Creating isolated virtual environment (.venv)..."
    if ! "$PORTABLE_DIR/bin/python3" -m venv "$VENV_DIR"; then
        echo "[ERROR] Failed to create virtual environment inside local runtime."
        exit 1
    fi
fi

echo "[OK] Running via local isolated virtual environment..."
exec "$VENV_DIR/bin/python" "$SCRIPT_DIR/ghostdag_calc.py" "$@"
