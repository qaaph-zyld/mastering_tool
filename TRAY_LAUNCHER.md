# Mastering Toolshop — Tray Launcher

Zero-command-line way to run the Mastering Toolshop web UI locally.

## What You Get

- **Double-click `Mastering_Toolshop.exe`** → tray icon appears
- **Browser opens automatically** at `http://127.0.0.1:5050`
- **Drag & drop WAV files**, select genre, run pipeline
- **Tray menu**: Open Browser | Restart Server | Exit

## Requirements

Same as before — must be installed on your machine:
- Python 3.x (with Flask, Pillow, pystray, requests)
- FFmpeg
- WSL2 + Ubuntu (for the mastering pipeline)

## Build the .exe (developers)

```powershell
cd "D:\Projects\Mastering_Toolshop"
pip install pyinstaller
python -m PyInstaller --onefile --noconsole --name "Mastering_Toolshop" --add-data "ui;ui" --add-data "*.sh;." ui\launcher.py
```

Output: `dist\Mastering_Toolshop.exe` (~29 MB)

## Files

| File | Purpose |
|---|---|
| `ui/launcher.py` | Tray app source |
| `dist/Mastering_Toolshop.exe` | Ready-to-run executable |
| `ui/server.py` | Flask backend (started silently by launcher) |

## How It Works

1. `launcher.py` starts `python ui/server.py` as a hidden subprocess
2. Polls `http://127.0.0.1:5050/api/genres` every 500ms until ready
3. Opens your default browser automatically
4. Shows a system tray icon with controls
5. On Exit: gracefully kills the server + WSL child processes
