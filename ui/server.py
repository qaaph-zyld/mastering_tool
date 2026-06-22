#!/usr/bin/env python3
"""
Mastering Toolshop Web UI — Flask backend
Handles WAV upload, runs wsl_run.sh via subprocess, streams stdout via SSE.
"""
import os
import platform
import re
import shutil
import subprocess
import tempfile
import urllib.parse
from datetime import datetime
from pathlib import Path

from flask import Flask, Response, jsonify, render_template, request, send_file

IS_WINDOWS = platform.system() == "Windows"

PROJECT_ROOT = Path(__file__).parent.parent.resolve()
RAW_WAV_DIR = PROJECT_ROOT / "music_tracks" / "raw_wav_files"
MASTER_DIR = RAW_WAV_DIR / "master"
UPLOAD_DIR = Path(tempfile.gettempdir()) / "mastering_toolshop_uploads"
UPLOAD_DIR.mkdir(exist_ok=True)
RAW_WAV_DIR.mkdir(parents=True, exist_ok=True)
MASTER_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR = PROJECT_ROOT / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

app = Flask(__name__, template_folder="templates", static_folder="static")

# ---- Genres scraped from family_policy.sh ----
GENRES = [
    {"value": "", "label": "Default (House / Hardcore Pop)"},
    {"value": "archival", "label": "Archival (-10.0 LUFS)"},
    {"value": "club", "label": "Club (-8.5 LUFS)"},
    {"value": "streaming", "label": "Streaming (-14.0 LUFS)"},
    {"value": "hiphop", "label": "Hip-Hop (-8.0 LUFS)"},
    {"value": "german_rap", "label": "German Rap (-9.0 LUFS)"},
    {"value": "german_drill", "label": "German Drill (-8.0 LUFS)"},
    {"value": "serbian_drill", "label": "Serbian Drill (-8.5 LUFS)"},
    {"value": "house", "label": "House (-8.5 LUFS)"},
]


def _safe_name(name: str) -> str:
    """Sanitize output name for bash."""
    return re.sub(r"[^A-Za-z0-9_]", "_", name).strip("_")[:60]


def _find_wsl_source_name(filename: str) -> str:
    """Convert Windows temp path to WSL /mnt/ path, or return as-is on Linux."""
    if not IS_WINDOWS:
        return str(Path(filename).resolve())
    p = Path(filename).resolve()
    drive = p.drive.lower().rstrip(":")
    rest = str(p).replace(p.drive, "", 1).replace("\\", "/")
    return f"/mnt/{drive}{rest}"


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/genres")
def api_genres():
    return jsonify(GENRES)


@app.route("/api/upload", methods=["POST"])
def api_upload():
    if "file" not in request.files:
        return jsonify({"error": "No file part"}), 400
    f = request.files["file"]
    if f.filename == "":
        return jsonify({"error": "Empty filename"}), 400
    if not f.filename.lower().endswith(".wav"):
        return jsonify({"error": "Only .wav files accepted"}), 400

    saved = UPLOAD_DIR / f.filename
    f.save(saved)
    # Also copy into project tree so outputs land in project master/
    project_inbox = RAW_WAV_DIR / f.filename
    project_inbox.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(saved, project_inbox)
    return jsonify({
        "ok": True,
        "filename": f.filename,
        "path": str(project_inbox),
    })


@app.route("/api/run")
def api_run():
    """SSE endpoint: streams pipeline stdout line-by-line."""
    file_path = request.args.get("path", "")
    genre = request.args.get("genre", "")
    vocal_prep = request.args.get("vocal_prep", "0")
    output_name = request.args.get("output_name", "")

    if not file_path or not os.path.isfile(file_path):
        def err():
            yield "data: [ERROR] Uploaded file not found\n\n"
            yield "event: done\ndata: {\"error\":\"File not found\"}\n\n"
        return Response(err(), mimetype="text/event-stream")

    wsl_path = _find_wsl_source_name(file_path)
    name = _safe_name(output_name) if output_name else "MASTER"

    def generate():
        env = os.environ.copy()
        env["VOCAL_PREP_ENABLE"] = "1" if vocal_prep == "1" else "0"
        if IS_WINDOWS:
            # WSL2 path
            project_wsl = f"/mnt/d/Projects/Mastering_Toolshop"
            project_win = str(PROJECT_ROOT / "music_tracks" / "raw_wav_files").replace("/", "\\")
            cmd = [
                "wsl", "-d", "Ubuntu", "-e", "bash", "-c",
                f"cd {project_wsl} && VOCAL_PREP_ENABLE={env['VOCAL_PREP_ENABLE']} bash wsl_run.sh '{wsl_path}' {name} {genre} '{project_win}'"
            ]
        else:
            # Native Linux (Docker/VPS)
            project_dir = str(PROJECT_ROOT / "music_tracks" / "raw_wav_files")
            cmd = [
                "bash", "wsl_run.sh", wsl_path, name, genre, project_dir
            ]
            env["VOCAL_PREP_ENABLE"] = env["VOCAL_PREP_ENABLE"]

        log_ts = datetime.now().strftime("%Y-%m-%d_%H%M%S")
        log_path = LOG_DIR / f"{log_ts}_{name}.log"

        with open(log_path, "w", encoding="utf-8") as log_f:
            header1 = f"[UI] Starting pipeline: genre={genre or 'default'}, vocal_prep={env['VOCAL_PREP_ENABLE']}"
            header2 = f"[UI] WSL source: {wsl_path}"
            log_f.write(header1 + "\n")
            log_f.write(header2 + "\n")

            yield f"data: {header1}\n\n"
            yield f"data: {header2}\n\n"

            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                cwd=str(PROJECT_ROOT),
            )

            try:
                for line in proc.stdout:
                    line = line.rstrip("\n")
                    log_f.write(line + "\n")
                    log_f.flush()
                    yield f"data: {line}\n\n"
            except GeneratorExit:
                proc.kill()
                return

            proc.wait()
            rc = proc.returncode
            log_f.write(f"[EXIT] rc={rc}\n")

        # Find output files
        files = []
        for ext in ("_MASTER_32f.wav", "_MASTER_16.wav", "_MASTER.mp3"):
            fpath = MASTER_DIR / f"{name}{ext}"
            if fpath.exists():
                fname = fpath.name
                files.append({
                    "name": fname,
                    "url": f"/api/download/{urllib.parse.quote(fname)}",
                    "size": fpath.stat().st_size,
                })

        import json
        done_payload = json.dumps({
            "done": True,
            "exit_code": rc,
            "files": files,
        })
        yield f"event: done\ndata: {done_payload}\n\n"

    def safe_generate():
        try:
            yield from generate()
        except Exception as exc:
            import traceback
            yield f"data: [ERROR] {str(exc)}\n\n"
            for line in traceback.format_exc().splitlines():
                yield f"data: {line}\n\n"
            yield f"event: done\ndata: {{\"error\":\"{str(exc)}\"}}\n\n"

    return Response(safe_generate(), mimetype="text/event-stream")


@app.route("/api/download/<path:filename>")
def api_download(filename):
    fpath = MASTER_DIR / filename
    if not fpath.exists():
        return jsonify({"error": "File not found"}), 404
    return send_file(fpath, as_attachment=True)


if __name__ == "__main__":
    # Bind to 0.0.0.0 in Docker, 127.0.0.1 locally
    host = "0.0.0.0" if os.environ.get("FLASK_ENV") == "production" else "127.0.0.1"
    app.run(host=host, port=5050, debug=False)
