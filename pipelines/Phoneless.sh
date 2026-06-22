#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline (48 kHz native) — Phoneless_Hardcore_Pop
# Target: -10 LUFS integrated, <= -1.0 dBTP true peak (ALL deliverables)
# Chain: prep -> EQ -> gentle comp -> stereo -> 4x oversampled limit (192 kHz)
#
# Calibrated for THIS source (see analysis/premaster_diagnostic.txt):
#   -13.0 LUFS / LRA 3.4 / TP -2.0 dBFS / crest ~12.8 dB
#   Spectrum: full+even low end, SCOOPED presence (2-4k) & brilliance (4-8k)
#   Stereo: narrow-ish (mid/side gap ~10.4 dB), well balanced
#   => light compression, presence/brilliance/air lift, modest widening
#
# Usage: bash master_pipeline_phoneless.sh <source.wav> <output_name> <project_dir>
# ============================================================
set -e

SOURCE="${1:-source/Phoneless_Hardcore_Pop.wav}"
NAME="${2:-Phoneless_Hardcore_Pop}"
PROJECT_DIR="${3:-.}"

# --- Tunable parameters (calibrated for THIS source) ---
PREGAIN_DB="${PREGAIN_DB:-12.5}"   # loudness gain into the limiter (tuned to hit -10 LUFS)
LIMIT_LOSSLESS="0.85"             # oversampled ceiling for WAV masters (~ -1.4 dBTP final)
LIMIT_MP3="0.82"                  # oversampled ceiling for MP3 source  (~ -1.0 dBTP after lossy encode)
OS_RATE="192000"                  # 4x oversample of 48 kHz
NATIVE_RATE="48000"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE  (native ${NATIVE_RATE} Hz)  PREGAIN=${PREGAIN_DB}dB"

# --- STAGE A: Headroom + DC removal + subsonic HPF ---
echo "[A] Headroom (-6dB), DC removal (-0.000215), HPF 25Hz/12dB"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-6dB,dcshift=-0.000215,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (lift the scooped top, anchor the low end) ---
# -0.8dB @ 220Hz Q1.2 -> gentle low-mid clarity (prevents boxiness as top is lifted)
# +0.6dB @ 55Hz  Q1.2 -> sub/fundamental anchor (punch for the genre)
# +2.2dB @ 3kHz  Q1.0 -> PRESENCE: the main fix (vocal/lead clarity, source recessed)
# +1.8dB @ 6.5k  Q1.0 -> brilliance/edge (weakest band in source)
# +1.5dB @ 12k   Q0.7 -> broad air lift (pop sheen)
echo "[B] Parametric EQ (presence/brilliance/air lift)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=220:t=q:w=1.2:g=-0.8,\
equalizer=f=55:t=q:w=1.2:g=0.6,\
equalizer=f=3000:t=q:w=1.0:g=2.2,\
equalizer=f=6500:t=q:w=1.0:g=1.8,\
equalizer=f=12000:t=q:w=0.7:g=1.5" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Gentle bus compression (glue) ---
# Source LRA already 3.4 and crest ~12.8 dB -> stay light; slow attack preserves transients
echo "[C] Gentle glue comp (1.6:1 @ -18dB, 25ms attack)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-18dB:ratio=1.6:attack=25:release=180:makeup=1.0:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Stereo widening (modest) + headroom prep ---
# Source mid/side gap ~10.4 dB (narrow). Widen modestly; keep mono-safe ("Phoneless").
echo "[D] Stereo widening (12%) + headroom prep (-3dB)"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "extrastereo=m=1.12,volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E1: 4x oversampled limiting for LOSSLESS masters ---
echo "[E1] 4x oversampled limit for WAV (+${PREGAIN_DB}dB / ${OS_RATE} / ceiling ${LIMIT_LOSSLESS})"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+${PREGAIN_DB}dB,\
aresample=${OS_RATE}:resampler=soxr:precision=28,\
alimiter=limit=${LIMIT_LOSSLESS}:attack=2:release=80:level=disabled,\
aresample=${NATIVE_RATE}:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05_limited.wav" 2>/dev/null

# --- STAGE E2: separate, lower-ceiling source for MP3 (lossy true-peak safety) ---
echo "[E2] 4x oversampled limit for MP3 source (ceiling ${LIMIT_MP3})"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+${PREGAIN_DB}dB,\
aresample=${OS_RATE}:resampler=soxr:precision=28,\
alimiter=limit=${LIMIT_MP3}:attack=2:release=80:level=disabled,\
aresample=${NATIVE_RATE}:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05_limited_mp3src.wav" 2>/dev/null

# --- DELIVERABLES ---
echo "[F] Deliverable 1: 32-bit float WAV 48k (archival)"
cp "$INT/05_limited.wav" "$OUT/${NAME}_MASTER_32f.wav"

echo "[F] Deliverable 2: 16-bit WAV 48k + TPDF dither (distribution)"
ffmpeg -hide_banner -nostats -y -i "$INT/05_limited.wav" \
    -af "aresample=osf=s16:dither_method=triangular_hp" \
    -c:a pcm_s16le "$OUT/${NAME}_MASTER_16.wav" 2>/dev/null

echo "[F] Deliverable 3: 320 kbps CBR MP3 (joint stereo, from true-peak-safe source)"
ffmpeg -hide_banner -nostats -y -i "$INT/05_limited_mp3src.wav" \
    -c:a libmp3lame -b:a 320k -joint_stereo 1 \
    "$OUT/${NAME}_MASTER.mp3" 2>/dev/null

echo ""
echo "============ FINAL LOUDNESS REPORT ============"
for f in "$OUT/${NAME}_MASTER_32f.wav" "$OUT/${NAME}_MASTER_16.wav" "$OUT/${NAME}_MASTER.mp3"; do
    echo ""
    echo "$(basename "$f")"
    ffmpeg -hide_banner -nostats -i "$f" \
        -af "ebur128=peak=true:framelog=quiet" -f null - 2>&1 | \
        tail -16 | grep -E "I:|LRA:|Peak:"
done

echo ""
echo "Done. Deliverables in: $OUT/"
