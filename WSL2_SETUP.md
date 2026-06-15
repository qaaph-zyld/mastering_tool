# WSL2 Setup Guide for Mastering Pipeline

## Prerequisites Verified
- WSL2 with Ubuntu 26.04 LTS installed and running
- `python3` and `bash` available

## One-Time Dependency Installation

Run these commands **inside WSL2** (open a WSL2 terminal: `wsl -d Ubuntu`):

```bash
sudo apt update
sudo apt install -y ffmpeg lilv-utils lsp-plugins-lv2 python3 python3-pip sox libsox-fmt-all
pip3 install matchering
```

## LV2 Plugin Setup (Optional)

Airwindows clippers are available but **not used by default** on WSL2 because `lv2apply` processes audio one sample at a time (~4% real-time = ~20 min for a 2:22 track). The pipeline now uses a fast native FFmpeg soft-clip by default.

If you want to experiment with LV2 clippers anyway:

```bash
# Extract inside WSL2:
cd /mnt/d/Projects/Mastering_Toolshop
sudo tar -xzf Airwindows_clippers.lv2.tar.gz -C /usr/local/lib/lv2/

# Verify plugins are visible:
export LV2_PATH=/usr/local/lib/lv2:/usr/lib/x86_64-linux-gnu/lv2:/usr/lib/lv2
lv2ls | grep -E 'lsp|airwindows|cliponly2'

# Add to ~/.bashrc:
echo 'export LV2_PATH=/usr/local/lib/lv2:/usr/lib/x86_64-linux-gnu/lv2:/usr/lib/lv2' >> ~/.bashrc
```

To force an LV2 clipper instead of the fast FFmpeg default:

```bash
E0_CLIPPER=lsp bash wsl_run.sh "..." track_name serbian_drill   # LSP clipper (~20 min)
E0_CLIPPER=cliponly2 bash wsl_run.sh "..." track_name serbian_drill  # Airwindows (~55 min)
```

## Windows Path Translation

The wrapper script `wsl_run.sh` handles conversion of Windows paths (`D:\Projects\...`) to WSL paths (`/mnt/d/Projects/...`).

## Usage

From Windows PowerShell or CMD:

```powershell
# Run the wrapper with a Windows path to your source WAV
# Runtime: ~30-60 seconds for a 2:22 track (fast ffmpeg soft-clip path)
wsl -d Ubuntu bash /mnt/d/Projects/Mastering_Toolshop/wsl_run.sh "D:\Projects\Mastering_Toolshop\source.wav" track_name

# With a genre profile:
wsl -d Ubuntu bash /mnt/d/Projects/Mastering_Toolshop/wsl_run.sh "D:\Projects\Mastering_Toolshop\source.wav" track_name hiphop

# With vocal prep + genre:
VOCAL_PREP_ENABLE=1 wsl -d Ubuntu bash /mnt/d/Projects/Mastering_Toolshop/wsl_run.sh "D:\Projects\Mastering_Toolshop\source.wav" track_name club
```

## Web UI (Drag & Drop)

A browser-based UI is available at `ui/` — drag a WAV file, pick a genre, toggle vocal prep, and run the pipeline with live log output.

### Start the UI

From Windows PowerShell or File Explorer:

```powershell
# Double-click this file:
D:\Projects\Mastering_Toolshop\ui\run.bat
```

Or from PowerShell:

```powershell
cd "D:\Projects\Mastering_Toolshop\ui"
python -m pip install -r requirements.txt
python server.py
# Then open http://127.0.0.1:5050 in your browser
```

### UI Features

- **Drag & drop** any `.wav` onto the zone
- **Genre profile** dropdown (populated from `family_policy.sh`)
- **Vocal prep** checkbox for AI vocal humanization
- **Live log** stream showing pipeline stages A–F
- **Download links** for 32f WAV, 16-bit WAV, and 320 kbps MP3 on completion

## Outputs

All outputs land under the project directory (translated to WSL paths automatically):
- `analysis/` — premaster diagnostic, spectrograms
- `intermediate/` — per-stage WAVs
- `master/` — final deliverables (32f, 16-bit, MP3)
- `verification/` — MD5, QC, translation reports
