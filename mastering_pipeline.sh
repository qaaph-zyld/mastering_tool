#!/usr/bin/env bash
# =============================================================================
# Mastering Pipeline v1.0 — open-source (FFmpeg only)
# Designed for loud, modern mixes that arrive already limited.
# =============================================================================
set -euo pipefail

INPUT="${1:?Usage: pipeline.sh <input> <output_basename>}"
OUTBASE="${2:?Usage: pipeline.sh <input> <output_basename>}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGES="$PROJECT_DIR/03_stages"
MASTER="$PROJECT_DIR/04_master"
TARGET_LUFS="${TARGET_LUFS:--9.0}"      # Integrated loudness target
TARGET_TP="${TARGET_TP:--1.0}"          # True-peak ceiling (dBTP)
TARGET_LRA="${TARGET_LRA:-7.0}"         # Loudness range target

mkdir -p "$STAGES" "$MASTER"

# -----------------------------------------------------------------------------
# CHAIN BREAKDOWN
# -----------------------------------------------------------------------------
# 1. dcshift          – kill any residual DC offset
# 2. highpass 28 Hz   – clean sub-rumble below musical content
# 3. equalizer 80     – +0.6 dB warmth bell (Q=1.2)
# 4. equalizer 250    – -1.5 dB de-mud bell  (Q=1.0)
# 5. equalizer 450    – -0.8 dB box tame     (Q=1.2)
# 6. equalizer 4000   – +1.2 dB presence     (Q=0.9) – vocal/lead clarity
# 7. equalizer 12000  – +1.5 dB air shelf    (Q=0.7)
# 8. acompressor      – glue: ratio 1.6, very slow, ~1 dB GR max
# 9. aexciter         – subtle harmonic warmth on highs
# 10. stereotools     – widen sides only on mids/highs (bass stays mono via
#                       sidechain feel: we use slev=1.08, mlev=1.0)
# 11. loudnorm        – two-pass-style linear loudnorm to TARGET_LUFS / TARGET_TP
# 12. alimiter        – brickwall safety net at TARGET_TP (catches inter-sample)
# -----------------------------------------------------------------------------

CHAIN="
dcshift=shift=0,
highpass=f=28:p=2,
equalizer=f=80:t=q:w=1.2:g=0.6,
equalizer=f=250:t=q:w=1.0:g=-1.5,
equalizer=f=450:t=q:w=1.2:g=-0.8,
equalizer=f=4000:t=q:w=0.9:g=1.2,
equalizer=f=12000:t=q:w=0.7:g=1.5,
acompressor=threshold=-18dB:ratio=1.6:attack=30:release=250:makeup=1:knee=6,
aexciter=level_in=1:level_out=1:amount=1.2:drive=4:blend=0:freq=7500:ceil=12000,
stereotools=mlev=1.0:slev=1.08:sbal=0:mpan=0:phase=0,
loudnorm=I=${TARGET_LUFS}:TP=${TARGET_TP}:LRA=${TARGET_LRA}:linear=true:print_format=summary,
alimiter=level_in=1:level_out=1:limit=$(awk "BEGIN{printf \"%.4f\", 10^(${TARGET_TP}/20)}"):attack=5:release=50:asc=1
"

echo ">>> Rendering 32-bit float WAV master ..."
ffmpeg -y -hide_banner -i "$INPUT" \
  -af "$CHAIN" \
  -ar 44100 -c:a pcm_f32le \
  "$MASTER/${OUTBASE}_master.wav" 2>&1 | tail -25

echo ""
echo ">>> Rendering 16-bit dithered WAV (CD/distribution-ready) ..."
ffmpeg -y -hide_banner -i "$MASTER/${OUTBASE}_master.wav" \
  -af "aresample=osf=s16:dither_method=triangular_hp" \
  -ar 44100 -c:a pcm_s16le \
  "$MASTER/${OUTBASE}_master_16bit.wav" 2>&1 | tail -3

echo ""
echo ">>> Rendering 320 kbps MP3 (streaming/sharing) ..."
ffmpeg -y -hide_banner -i "$MASTER/${OUTBASE}_master.wav" \
  -c:a libmp3lame -b:a 320k -ar 44100 \
  -metadata title="MiXaLL x ZIVOT LEP BB (Mastered)" \
  "$MASTER/${OUTBASE}_master.mp3" 2>&1 | tail -3

echo ""
echo ">>> Done."
