#!/usr/bin/env python3
"""
Mastering Toolshop Web UI — Flask backend
Handles WAV upload, runs wsl_run.sh via subprocess, streams stdout via SSE.
"""
import os
import re
import shutil
import subprocess
import tempfile
import urllib.parse
from pathlib import Path

from flask import Flask, Response, jsonify, render_template, request, send_file

PROJECT_ROOT = Path(__file__).parent.parent.resolve()
MASTER_DIR = PROJECT_ROOT / "music_tracks" / "raw_wav_files" / "master"
UPLOAD_DIR = Path(tempfile.gettempdir()) / "mastering_toolshop_uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

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
    """Convert Windows temp path to WSL /mnt/ path."""
    # filename comes from uploaded file; we stored it in Windows temp
    # e.g. C:\Users\...\AppData\Local\Temp\mastering_toolshop_uploads\foo.wav
    # Convert to /mnt/c/Users/.../AppData/Local/Temp/.../foo.wav
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
    project_inbox = PROJECT_ROOT / "music_tracks" / "raw_wav_files" / f.filename
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
        # WSL2 project dir
        project_wsl = f"/mnt/d/Projects/Mastering_Toolshop"
        project_win = str(PROJECT_ROOT / "music_tracks" / "raw_wav_files").replace("/", "\\")

        cmd = [
            "wsl", "-d", "Ubuntu", "-e", "bash", "-c",
            f"cd {project_wsl} && VOCAL_PREP_ENABLE={env['VOCAL_PREP_ENABLE']} bash wsl_run.sh '{wsl_path}' {name} {genre} '{project_win}'"
        ]

        yield f"data: [UI] Starting pipeline: genre={genre or 'default'}, vocal_prep={env['VOCAL_PREP_ENABLE']}\n\n"
        yield f"data: [UI] WSL source: {wsl_path}\n\n"

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
                yield f"data: {line}\n\n"
        except GeneratorExit:
            proc.kill()
            return

        proc.wait()
        rc = proc.returncode

        # Find output files
        files = []
        for ext in ("_MASTER_32f.wav", "_MASTER_16.wav", "_MASTER.mp3"):
            fpath = MASTER_DIR / f"{name}{ext}"
            if fpath.exists():
                files.append({
                    "name": f.name,
                    "url": f"/api/download/{urllib.parse.quote(f.name)}",
                    "size": fpath.stat().st_size,
                })

        import json
        done_payload = json.dumps({
            "done": True,
            "exit_code": rc,
            "files": files,
        })
        yield f"event: done\ndata: {done_payload}\n\n"

    return Response(generate(), mimetype="text/event-stream")


@app.route("/api/download/<path:filename>")
def api_download(filename):
    fpath = MASTER_DIR / filename
    if not fpath.exists():
        return jsonify({"error": "File not found"}), 404
    return send_file(fpath, as_attachment=True)


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5050, debug=False)
