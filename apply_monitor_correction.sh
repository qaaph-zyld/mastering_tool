#!/bin/bash
# ============================================================
# apply_monitor_correction.sh  —  monitoring/translation correction
# ------------------------------------------------------------
# Convolves a room (DRC-FIR) or headphone (AutoEq) correction FIR
# into a signal via FFmpeg `afir`, for LISTENING REFERENCE only.
#
# IMPORTANT: this is for the MONITOR path (what you hear while you
# work / reference-check), NOT the deliverable. Never bake room or
# headphone correction into a master.
#
# The correction FIR is supplied as an impulse WAV:
#   - Room: measure impulse (REW / sweep+lsconv) -> DRC-FIR -> FIR.wav
#   - Headphones: AutoEq --convolution-eq export -> FIR.wav
# This script is the apply step and is ready the moment you have one.
#
# Usage: bash apply_monitor_correction.sh <in.wav> <fir.wav> <out.wav>
# ============================================================
set -e
IN="$1"; FIR="$2"; OUT="$3"
[ -z "$OUT" ] && { echo "Usage: $0 <in.wav> <fir.wav> <out.wav>"; exit 1; }
[ -f "$FIR" ] || { echo "correction FIR not found: $FIR"; exit 1; }

INCH=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$IN")

# afir is faithful and gain-transparent (gtype=-1) only when input and IR
# channel counts match cleanly. For a single mono correction curve on a
# stereo signal, split -> convolve each channel through the mono FIR ->
# rejoin. (A true per-channel stereo correction would supply L/R FIRs.)
if [ "$INCH" = "2" ]; then
  ffmpeg -hide_banner -nostats -y -i "$IN" -i "$FIR" -filter_complex "
    [0:a]channelsplit=channel_layout=stereo[L][R];
    [1:a]asplit=2[irL][irR];
    [L][irL]afir=gtype=-1[Lc];
    [R][irR]afir=gtype=-1[Rc];
    [Lc][Rc]join=inputs=2:channel_layout=stereo[out]" \
    -map "[out]" -c:a pcm_f32le "$OUT" 2>/dev/null
else
  ffmpeg -hide_banner -nostats -y -i "$IN" -i "$FIR" \
    -filter_complex "[0:a][1:a]afir=gtype=-1[out]" \
    -map "[out]" -c:a pcm_f32le "$OUT" 2>/dev/null
fi

echo "[apply_monitor_correction] $IN  *  $FIR  ->  $OUT  (monitor reference only)"
