#!/bin/bash
# ============================================================
# lv2_stage.sh  —  generic latency-compensated LV2 stage runner
# ------------------------------------------------------------
# Hosts ANY lv2apply-compatible plugin as a deterministic,
# sample-aligned pipeline stage. Auto-calibrates the plugin's
# latency with an impulse at the file's sample rate USING THE
# SAME control settings, then pad/process/trim to realign and
# preserve the tail. One runner for all conditional LV2 stages
# (multiband comp, dynamic EQ, etc.) so each new stage is a
# parameter set, not a new script.
#
# Usage:
#   bash lv2_stage.sh <in.wav> <out.wav> <URI> [-c SYM VAL]...
#
# Examples:
#   # Multiband compressor (conditional glue), conservative defaults:
#   bash lv2_stage.sh in.wav out.wav \
#     http://lsp-plug.in/plugins/lv2/mb_compressor_stereo
#
#   # Dynamic EQ role via dyna_processor on a sidechain band:
#   bash lv2_stage.sh in.wav out.wav \
#     http://lsp-plug.in/plugins/lv2/dyna_processor_stereo -c al 1
#
# Determinism: verify with an MD5 double-run (caller's gate).
# Plugins with internal dither/RNG must be checked; keep dither
# OFF here and apply final TPDF dither as the single controlled step.
# ============================================================
set -e
IN="$1"; OUT="$2"; URI="$3"; shift 3 || { echo "Usage: $0 <in> <out> <URI> [-c SYM VAL]..."; exit 1; }
CTRL=("$@")   # passthrough control-port args

SR=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate \
       -of default=noprint_wrappers=1:nokey=1 "$IN")
TMP=$(mktemp -d)

# --- calibrate latency at THIS sample rate + THESE controls ---
python3 - "$SR" "$TMP/imp.wav" <<'PY'
import sys,numpy as np,soundfile as sf
fs=int(sys.argv[1]); x=np.zeros((16384,2),dtype=np.float32); x[4000,:]=0.03
sf.write(sys.argv[2],x,fs,subtype='FLOAT')
PY
lv2apply -i "$TMP/imp.wav" -o "$TMP/impP.wav" "${CTRL[@]}" "$URI" 2>/dev/null
LAT=$(python3 - "$TMP/imp.wav" "$TMP/impP.wav" <<'PY'
import sys,numpy as np,soundfile as sf
xi,_=sf.read(sys.argv[1]); xo,_=sf.read(sys.argv[2])
print(int(np.argmax(np.abs(xo[:,0])) - np.argmax(np.abs(xi[:,0]))))
PY
)
[ "$LAT" -lt 0 ] && LAT=0
echo "[lv2_stage] $(basename "$URI")  sr=$SR  latency=$LAT samples"

# --- pad -> process -> trim ---
ffmpeg -hide_banner -nostats -y -i "$IN" -af "apad=pad_len=$((LAT+64))" "$TMP/inp.wav" 2>/dev/null
lv2apply -i "$TMP/inp.wav" -o "$TMP/outp.wav" "${CTRL[@]}" "$URI" 2>/dev/null
ffmpeg -hide_banner -nostats -y -i "$TMP/outp.wav" \
  -af "atrim=start_sample=$LAT,asetpts=N/SR/TB" "$OUT" 2>/dev/null
rm -rf "$TMP"
