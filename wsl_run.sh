#!/bin/bash
# ============================================================
# wsl_run.sh  —  WSL2 wrapper for master_pipeline_v3.sh
# ------------------------------------------------------------
# Translates Windows paths to WSL paths, sets LV2_PATH,
# and delegates to the canonical v3 orchestrator.
#
# Usage from Windows:
#   wsl -d Ubuntu bash /mnt/d/Projects/Mastering_Toolshop/wsl_run.sh \
#       "D:\\Projects\\Mastering_Toolshop\\source.wav" track_name [profile]
#
# Environment (all optional):
#   VOCAL_PREP_ENABLE=1  — run vocal_prep.sh before mastering
#   MULTIBAND_ENABLE=1   — enable conditional multiband stage
#   BASS_MONO_ENABLE=1   — enable bass-mono
#   PREGAIN_DB=7.1       — override pre-gain
# ============================================================
set -e

# ---- path translator: D:\Projects\... -> /mnt/d/Projects/... ----
win_to_wsl() {
    local p="$1"
    # Replace backslashes with forward slashes
    p="${p//\\//}"
    # Convert C:/ -> /mnt/c/, D:/ -> /mnt/d/, etc.
    if [[ "$p" =~ ^([A-Za-z]):/(.*) ]]; then
        echo "/mnt/${BASH_REMATCH[1],,}/${BASH_REMATCH[2]}"
    else
        echo "$p"
    fi
}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- environment ----
export LV2_PATH="${LV2_PATH:-/usr/local/lib/lv2:/usr/lib/x86_64-linux-gnu/lv2:/usr/lib/lv2}"

# ---- arguments ----
WIN_SOURCE="$1"
NAME="${2:-master}"
PROFILE="${3:-}"
PROJECT_DIR_WIN="${4:-$(dirname "$WIN_SOURCE")}"

# ---- path translation ----
SOURCE="$(win_to_wsl "$WIN_SOURCE")"
PROJECT_DIR="$(win_to_wsl "$PROJECT_DIR_WIN")"

# Validate source exists inside WSL
if [ ! -f "$SOURCE" ]; then
    echo "ERROR: source not found inside WSL: $SOURCE"
    echo "  (original Windows path: $WIN_SOURCE)"
    exit 1
fi

echo ">>> WSL2 wrapper"
echo "    Windows source: $WIN_SOURCE"
echo "    WSL source:     $SOURCE"
echo "    Name:           $NAME"
echo "    Profile:        ${PROFILE:-(default house)}"
echo "    Project dir:    $PROJECT_DIR"
echo "    LV2_PATH:       $LV2_PATH"

# ---- optional vocal prep ----
if [ "${VOCAL_PREP_ENABLE:-0}" = "1" ] && [ -f "$HERE/vocal_prep.sh" ]; then
    echo ">>> Running vocal prep..."
    VP_OUT="$PROJECT_DIR/intermediate/vocal_prep.wav"
    mkdir -p "$(dirname "$VP_OUT")"
    bash "$HERE/vocal_prep.sh" "$SOURCE" "$VP_OUT"
    SOURCE="$VP_OUT"
    echo ">>> Vocal prep done. New source: $SOURCE"
fi

# ---- delegate to v3 orchestrator ----
bash "$HERE/master_pipeline_v3.sh" "$SOURCE" "$NAME" "$PROJECT_DIR" "$PROFILE"

echo ""
echo "============ WSL2 WRAPPER DONE ============"
echo "  Outputs in: $PROJECT_DIR/{analysis,intermediate,master,verification}"
