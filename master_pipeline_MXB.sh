#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline (44.1 kHz native) — MIXALL_x_BORBA_24
# Target: -10.0 LUFS integrated, <= -1.0 dBTP true peak (ALL deliverables)
# Chain: prep -> EQ -> light glue -> stereo(NEUTRAL) -> 4x oversampled limit (176.4 kHz)
#
# TUNED FOR THIS SOURCE (LOUD, DENSE, ALREADY-CLIPPING, DARK-TOP, PHASE-RISKY):
#   - source is -10.7 LUFS (near target) BUT +1.8 dBTP -> inter-sample CLIPPING is the
#     primary problem; modest pre-gain, the limiter's real job is taming the overshoot
#   - LRA 4.8 / crest ~12.7 dB (already dense) -> LIGHT glue only
#   - dark-top, mid-forward: lift recessed presence/brilliance/air (2-16k);
#     gentle cut on the 500Hz-1k mid bump that crowds the vocal
#   - min phase correlation -0.64 -> FAILS mono safety -> WIDENING SKIPPED (m=1.0),
#     stage retained in architecture, only headroom prep applied
#   - native 44.1 kHz preserved end-to-end (oversample 4x = 176.4 kHz)
#   - dedicated lower-ceiling MP3 source (E2) so lossy true peak stays <= -1.0
#
# Usage: bash master_pipeline_MXB.sh <source.wav> <output_name> <project_dir>
# ============================================================
set -e

SOURCE="${1:-source/MIXALL_x_BORBA_24.wav}"
NAME="${2:-MIXALL_x_BORBA_24}"
PROJECT_DIR="${3:-.}"

# --- Tunable parameters (calibrated for THIS source) ---
PREGAIN_DB="11.3"      # CALIBRATED: -> -10.1 LUFS (sweep: 11.0=-10.2, 11.3=-10.1, 12.0=-9.7, 13.0=-9.2)
LIMIT_LOSSLESS="0.85"  # oversampled ceiling for WAV masters  (~ -1.4 dBTP final)
LIMIT_MP3="0.77"       # oversampled ceiling for MP3 source   (lossy true-peak safety)
OS_RATE="176400"       # 4x oversample of 44.1 kHz
NATIVE_RATE="44100"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT"
mkdir -p "$OUT"

echo ">>> Source: $SOURCE  (native ${NATIVE_RATE} Hz)"

# --- STAGE A: Headroom + DC removal + subsonic HPF ---
echo "[A] Headroom (-6dB), DC removal (-0.00028), HPF 25Hz/12dB"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-6dB,dcshift=-0.00028,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (dark-top, mid-forward profile) ---
# -1.5dB @ 600Hz Q1.0 -> tame the 500Hz-1k mid bump crowding the vocal
# +0.5dB @ 60Hz  Q1.2 -> light fundamental reinforcement (bass already strong)
# +1.3dB @ 3.5k  Q1.2 -> presence lift (recessed)
# +1.2dB @ 6.5k  Q1.0 -> brilliance/definition (recessed)
# +1.5dB @ 12k   Q0.7 -> broad air lift (top recessed, rolls off above)
echo "[B] Parametric EQ (dark-top, mid-forward profile)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=600:t=q:w=1.0:g=-1.5,\
equalizer=f=60:t=q:w=1.2:g=0.5,\
equalizer=f=3500:t=q:w=1.2:g=1.3,\
equalizer=f=6500:t=q:w=1.0:g=1.2,\
equalizer=f=12000:t=q:w=0.7:g=1.5" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (LIGHT glue) ---
# Source already dense (LRA 4.8) -> very light touch, slow attack preserves transients
echo "[C] Bus compression / light glue (1.4:1 @ -18dB, 30ms attack)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-18dB:ratio=1.4:attack=30:release=220:makeup=1.0:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Stereo stage (WIDENING SKIPPED) + headroom prep ---
# min phase correlation -0.64 FAILS mono safety -> no widening (m=1.0).
# Stage retained in architecture per framework; only -3dB headroom prep applied.
echo "[D] Stereo stage: WIDENING SKIPPED (m=1.0, phase-risky) + headroom prep (-3dB)"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "extrastereo=m=1.00,volume=-3dB" \
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
echo "[F] Deliverable 1: 32-bit float WAV 44.1k (archival)"
cp "$INT/05_limited.wav" "$OUT/${NAME}_MASTER_32f.wav"

echo "[F] Deliverable 2: 16-bit WAV 44.1k + TPDF dither (distribution)"
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
        grep -A 16 "Summary:" | grep -iE "I:|LRA:|True peak|Peak:"
done

echo ""
echo "Done. Deliverables in: $OUT/"
