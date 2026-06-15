#!/usr/bin/env python3
"""
Mastering Toolshop Tray Launcher
Auto-starts the Flask server, opens browser, provides tray controls.
"""
import datetime
import os
import subprocess
import sys
import tempfile
import threading
import time
import webbrowser
from pathlib import Path

import pystray
import requests
from PIL import Image, ImageDraw

# --- Config ---
if getattr(sys, 'frozen', False):
    # Running from PyInstaller bundle
    PROJECT_ROOT = Path(sys._MEIPASS)
else:
    PROJECT_ROOT = Path(__file__).parent.parent.resolve()
SERVER_SCRIPT = PROJECT_ROOT / "ui" / "server.py"
HOST = "127.0.0.1"
PORT = 5050
URL = f"http://{HOST}:{PORT}"
HEALTH_URL = f"{URL}/api/genres"
MAX_WAIT = 30  # seconds

_server_proc = None
_icon = None
_stop_event = threading.Event()


def _create_icon() -> Image.Image:
    """Generate a simple tray icon (64x64 purple circle with white M)."""
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Purple circle background
    draw.ellipse([2, 2, size - 2, size - 2], fill=(138, 43, 226, 255))
    # White "M" text
    try:
        from PIL import ImageFont
        font = ImageFont.truetype("arial.ttf", 36)
    except Exception:
        font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), "M", font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (size - text_w) // 2
    y = (size - text_h) // 2 - 4
    draw.text((x, y), "M", fill=(255, 255, 255, 255), font=font)
    return img


def _is_server_ready() -> bool:
    try:
        resp = requests.get(HEALTH_URL, timeout=1)
        return resp.status_code == 200
    except Exception:
        return False


def _get_python_exe() -> str:
    """Find the actual Python interpreter (not the PyInstaller .exe)."""
    if getattr(sys, 'frozen', False):
        # Running from PyInstaller bundle; sys.executable is the .exe itself
        import shutil
        for name in ('python', 'python3', 'py'):
            path = shutil.which(name)
            if path:
                return path
        raise RuntimeError("Cannot find python executable to start server.")
    return sys.executable


def _start_server() -> subprocess.Popen:
    """Start the Flask server as a hidden subprocess."""
    global _server_proc
    env = os.environ.copy()
    python_exe = _get_python_exe()
    # On Windows, create no console window
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    _server_proc = subprocess.Popen(
        [python_exe, str(SERVER_SCRIPT)],
        cwd=str(PROJECT_ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        creationflags=creationflags,
        env=env,
    )
    return _server_proc


def _kill_proc_tree(pid: int):
    """Kill process and all children (Windows)."""
    if sys.platform == "win32":
        subprocess.run(
            ["taskkill", "/T", "/F", "/PID", str(pid)],
            capture_output=True,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
    else:
        import signal
        os.killpg(os.getpgid(pid), signal.SIGTERM)


def _stop_server():
    global _server_proc
    if _server_proc and _server_proc.poll() is None:
        try:
            _kill_proc_tree(_server_proc.pid)
        except Exception:
            pass
        try:
            _server_proc.terminate()
            _server_proc.wait(timeout=5)
        except Exception:
            _server_proc.kill()
            _server_proc.wait()
    _server_proc = None


def _wait_for_server():
    """Poll until server responds or timeout."""
    for _ in range(MAX_WAIT * 2):
        if _stop_event.is_set():
            return False
        if _is_server_ready():
            return True
        time.sleep(0.5)
    return False


def _open_browser():
    webbrowser.open(URL)


def _restart_server():
    _stop_server()
    time.sleep(1)
    _start_server()
    if _wait_for_server():
        _open_browser()


def _on_open(icon, item):
    _open_browser()


def _on_restart(icon, item):
    threading.Thread(target=_restart_server, daemon=True).start()


def _on_exit(icon, item):
    _stop_event.set()
    _stop_server()
    icon.stop()


def _run_tray():
    global _icon
    icon_image = _create_icon()
    menu = pystray.Menu(
        pystray.MenuItem("Open Browser", _on_open),
        pystray.MenuItem("Restart Server", _on_restart),
        pystray.MenuItem("Exit", _on_exit),
    )
    _icon = pystray.Icon("mastering_toolshop", icon_image, "Mastering Toolshop", menu)
    _icon.run()


def _log(msg: str):
    import datetime
    ts = datetime.datetime.now().isoformat()
    line = f"[{ts}] {msg}\n"
    print(line, end="")
    try:
        log_path = Path(tempfile.gettempdir()) / "mastering_toolshop_launcher.log"
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(line)
    except Exception:
        pass


def main():
    _log("Starting Mastering Toolshop...")
    try:
        python_exe = _get_python_exe()
        _log(f"Using Python: {python_exe}")
    except Exception as e:
        _log(f"ERROR finding Python: {e}")
        sys.exit(1)

    _start_server()
    _log("Waiting for server...")
    if _wait_for_server():
        _log(f"Server ready at {URL}")
        _open_browser()
    else:
        _log("Server failed to start within timeout.")
        _stop_server()
        sys.exit(1)

    # Start tray in background thread
    tray_thread = threading.Thread(target=_run_tray, daemon=False)
    tray_thread.start()
    tray_thread.join()

    _log("Exiting.")
    _stop_server()


if __name__ == "__main__":
    main()
