#!/bin/bash
# ============================================================
# qc_translation.sh  —  translation testing matrix
# ------------------------------------------------------------
# Renders a master through simulated playback systems and logs a
# metrics table, so every master is auto-auditioned for how it
# travels. The mono fold-down level loss is the key correlation
# diagnostic: large loss => out-of-phase content collapsing.
#
# Renders:
#   phone   : bandpass ~400 Hz-8 kHz, bass reduced
#   earbuds : gentle HPF + slight bright tilt
#   car     : low-mid bump + cabin-ish resonance
#   clubPA  : sub-heavy, mono below 120 Hz
#   mono    : full mono fold-down (level-loss measured)
#
# Usage: bash qc_translation.sh <master.wav> <outdir>
# ============================================================
set -e
SRC="$1"; OUT="${2:-translation_out}"
[ -z "$SRC" ] && { echo "Usage: $0 <master.wav> <outdir>"; exit 1; }
mkdir -p "$OUT"

ilufs () { ffmpeg -hide_banner -nostats -i "$1" -af "ebur128=framelog=quiet" -f null - 2>&1 \
           | grep -E "^\s*I:" | tail -1 | awk '{print $2}'; }

render () { # label  filtergraph
  ffmpeg -hide_banner -nostats -y -i "$SRC" -af "$2" -c:a pcm_f32le "$OUT/sys_$1.wav" 2>/dev/null
  printf "  %-8s : %s LUFS\n" "$1" "$(ilufs "$OUT/sys_$1.wav")"
}

echo "============================================================"
echo " TRANSLATION MATRIX   master: $SRC"
echo "============================================================"
SRC_LUFS=$(ilufs "$SRC")
echo "  source   : $SRC_LUFS LUFS"
render phone   "highpass=f=400,lowpass=f=8000,bass=g=-6:f=120"
render earbuds "highpass=f=60,treble=g=2:f=8000"
render car     "equalizer=f=120:t=q:w=1:g=4,equalizer=f=2500:t=q:w=2:g=-3,equalizer=f=70:t=q:w=2:g=3"
render clubPA  "pan=stereo|c0=0.5*FL+0.5*FR|c1=0.5*FL+0.5*FR,bass=g=4:f=80"

# --- mono fold-down level-loss diagnostic ---
ffmpeg -hide_banner -nostats -y -i "$SRC" -af "pan=mono|c0=0.5*FL+0.5*FR" -c:a pcm_f32le "$OUT/sys_mono.wav" 2>/dev/null
MONO_LUFS=$(ilufs "$OUT/sys_mono.wav")
LOSS=$(python3 -c "print(round(($SRC_LUFS)-($MONO_LUFS),1))" 2>/dev/null || echo NA)
# A perfectly correlated stereo signal already reads ~3.0 LU above its mono
# sum (R128 channel-summing convention). Subtract that baseline so only
# genuine phase cancellation beyond it is flagged.
EXCESS=$(python3 -c "print(round($LOSS-3.0,1))" 2>/dev/null || echo NA)
echo "  mono     : $MONO_LUFS LUFS   (fold-down)"
echo ""
echo "  >>> MONO FOLD-DOWN LOSS = $LOSS LU   (excess beyond 3.0 LU R128 baseline = $EXCESS LU)"
python3 -c "print('  >>> VERDICT: '+('PHASE PROBLEM (excess cancellation on mono collapse)' if $EXCESS>1.5 else 'mono-compatible'))" 2>/dev/null || true
echo "============================================================"
