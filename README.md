# GHOSTDAG Parameter Calculator

An educational reference implementation and test harness for calculating GHOSTDAG parameters (`k`, anticone size expectation, probability distributions, and block time bounds).

---

## How to Run

1. Download and extract the repository ZIP file.
2. Open the directory containing the tool.
3. Double-click the launcher script for your system:
   * **Windows:** `run_on_win.bat`
   * **macOS / Linux:** `run_on_mac.sh`

---

## How the Auto-Installer Works

* **Python 3.13 Verification:** The script checks if Python 3.13 exists on your computer.
* **Zero Conflicts:** If Python 3.13 is not present, it downloads an official, self-contained Python 3.13 package into the local folder. It **will not** touch or modify your existing system files, path variables, or other installed Python versions.
* **Isolated Environment:** A dedicated virtual environment (`.venv`) is constructed strictly on Python 3.13.
* **Instant Start:** First launch takes ~10–30 seconds for initial setup. All future double-clicks launch instantly.

---

## macOS Permissions Setup (One-Time)

If macOS displays a permission prompt when running `run_on_mac.sh`:

1. Open **Terminal**.
2. Navigate to the tool folder:
   ```bash
   cd path/to/script/directory
   ```
3. Grant execution permissions:
   ```bash
   chmod +x run_on_mac.sh
   ```
4. Double-click `run_on_mac.sh` in Finder to launch anytime.

---

## Security & Transparency Checklist

You should never blindly run scripts downloaded from the Internet—including the ones in this repository. These launcher scripts are intentionally small so that anyone can inspect them before running them.

The launchers exist only to make the tool easier to run. They:

- Check whether Python 3.13 is already installed.
- Download a local Python 3.13 runtime **only if necessary**.
- Create an isolated Python virtual environment (`.venv`) inside this repository.
- Launch `ghostdag_calc.py`.

They do **not** install Python system-wide, modify your existing Python installation, change your system `PATH`, or require administrator/root privileges.

### 1. Open the launcher as plain text

Both launcher scripts are plain text files.

- **Windows:** Right-click `run_on_win.bat` and choose **Edit** or **Open With → Notepad**.
- **macOS / Linux:** Open `run_on_mac.sh` with any text editor.

No special software is required to inspect them.

### 2. Ask an AI assistant to explain the code

If you are not comfortable reading batch or shell scripts, you can copy and paste the contents into an AI assistant and ask questions such as:

- "Can you explain what this script does?"
- "Does this script perform any unexpected or unsafe actions?"
- "Does it download or execute anything?"
- "Does it modify files outside of this repository?"
- "Does it require administrator/root privileges?"

You can also review `ghostdag_calc.py` the same way, since it is the program the launcher ultimately runs.

> **Note:** AI can be a useful review tool, but it should not be treated as a guarantee of safety. If something appears unclear or inconsistent with the README, investigate further before running the software.

### 3. Look for common warning signs

Examples of behavior that deserves extra scrutiny include:

- Downloading and executing additional code from unknown sources.
- Running shell commands unrelated to the stated purpose of the tool.
- Reading personal files or browser data.
- Uploading information over the network.
- Modifying files outside of this repository.
- Requesting administrator (Windows) or root (macOS/Linux) privileges without a clear reason.
- Creating startup entries, scheduled tasks, or background services.

### 4. Verify the repository contents

A fresh download of this repository should contain only:

- `README.md`
- `ghostdag_calc.py`
- `run_on_win.bat`
- `run_on_mac.sh`

After running one of the launchers for the first time, it is also expected to contain:

- `.venv/` — the isolated Python virtual environment created for this tool.
- `python_313_runtime/` — a local Python runtime, **only if** Python 3.13 was not already installed on your computer.

No other files or directories are expected to be created by this project.

If you find unexpected executables, scripts, or files that are not described above, consider reviewing them before running the project.
