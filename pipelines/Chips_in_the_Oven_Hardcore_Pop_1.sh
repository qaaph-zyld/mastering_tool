#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline (48 kHz native) — Chips_in_the_Oven_Hardcore_Pop_1
# Target: -10.0 LUFS integrated, <= -1.0 dBTP true peak (ALL deliverables)
# Chain: prep -> EQ -> gentle glue comp -> stereo(bypass) -> 4x oversampled limit (192 kHz)
#
# Source profile (see analysis/premaster_diagnostic.txt):
#   -13.4 LUFS / LRA 3.9 / TP -2.1 dBTP / crest ~13.2 dB
#   DARK-TOP (bass-to-air gap ~12.8 dB) -> presence + brilliance + air lift
#   min phase correlation -0.91 -> STEREO WIDENING SKIPPED (mono-safety fail)
#   DC offset +3.1e-5 -> negligible -> DC correction bypassed (stage retained)
#
# Usage: bash master_pipeline.sh <source.wav> <output_name> <project_dir> [PREGAIN_DB]
# ============================================================
set -e

SOURCE="${1:-source/Chips_in_the_Oven_Hardcore_Pop_1.wav}"
NAME="${2:-Chips_in_the_Oven_Hardcore_Pop_1}"
PROJECT_DIR="${3:-.}"

# --- Tunable parameters (calibrated empirically for THIS source) ---
PREGAIN_DB="${4:-12.5}"   # final loudness gain into the limiter (calibrated below)
LIMIT_LOSSLESS="0.85"     # oversampled ceiling for WAV masters (~ -1.4 dBTP final)
LIMIT_MP3="0.82"          # oversampled ceiling for MP3 source (true-peak-safe after lossy encode)
OS_RATE="192000"          # 4x oversample of 48 kHz
NATIVE_RATE="48000"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT"
mkdir -p "$OUT"

echo ">>> Source: $SOURCE  (native ${NATIVE_RATE} Hz)  PREGAIN=${PREGAIN_DB}dB"

# --- STAGE A: Headroom + DC removal (bypassed) + subsonic HPF ---
# DC offset negligible (+3.1e-5) -> dcshift omitted; stage retained in architecture.
echo "[A] Headroom (-6dB), DC (bypassed - negligible), HPF 25Hz/12dB"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-6dB,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (tuned for THIS dark-top source) ---
# -0.8dB @ 220Hz Q1.1  -> light low-mid tightening (low-mids already clean, NO mud cut needed)
# +0.8dB @ 90Hz  Q1.3  -> reinforce fundamental / club weight
# +1.5dB @ 3kHz  Q1.2  -> presence (source recessed at -29 dB)
# +1.8dB @ 6kHz  Q1.0  -> brilliance lift (source dark at -30.6 dB)
# +2.5dB highshelf @ 10.5k -> broad air lift (real content to ~17k; dark top)
echo "[B] Parametric EQ (dark-top profile: presence + brilliance + air shelf)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=220:t=q:w=1.1:g=-0.8,\
equalizer=f=90:t=q:w=1.3:g=0.8,\
equalizer=f=3000:t=q:w=1.2:g=1.5,\
equalizer=f=6000:t=q:w=1.0:g=1.8,\
highshelf=f=10500:g=2.5:t=q:w=0.7" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Gentle bus compression (glue) ---
# Source LRA already 3.9 -> light touch; 30ms attack preserves club transients.
echo "[C] Gentle glue comp (1.5:1 @ -18dB, 30ms attack)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-18dB:ratio=1.5:attack=30:release=200:makeup=1.0:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Stereo stage (WIDENING SKIPPED) + headroom prep ---
# min phase correlation -0.91 -> extrastereo BYPASSED for mono-safety. Stage retained.
echo "[D] Stereo widening SKIPPED (mono-safety) + headroom prep (-3dB)"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E1: 4x oversampled limiting for LOSSLESS masters ---
echo "[E1] 4x oversampled limit for WAV (+${PREGAIN_DB}dB / ${OS_RATE} / ceiling ${LIMIT_LOSSLESS})"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+${PREGAIN_DB}dB,\
aresample=${OS_RATE}:resampler=soxr:precision=28,\
alimiter=limit=${LIMIT_LOSSLESS}:attack=2:release=80:level=disabled,\
aresample=${NATIVE_RATE}:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05_limited.wav" 2>/dev/null

# --- STAGE E2: separate lower-ceiling source for MP3 (lossy true-peak safety) ---
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
        tail -14 | grep -E "I:|LRA:|Peak:"
done
echo ""
echo "Done. Deliverables in: $OUT/"
