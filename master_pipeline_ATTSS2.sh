#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline (48 kHz native) — All_the_Things_She_Said_Hardcore_Pop_2
# Target: -10.0 LUFS integrated, <= -1.0 dBTP true peak (ALL deliverables)
# Chain: prep -> EQ -> glue comp -> stereo(NEUTRAL) -> 4x oversampled limit (192 kHz)
#
# TUNED FOR THIS SOURCE, as a deliberate delta from its direct sibling
# (All_the_Things_She_Said_Hardcore_Pop_1, mastered 2026-06-01):
#   - source -13.2 LUFS (quiet, +0.8 dB louder than Part 1's -14.0) with hot-but-
#     clean -0.7 dBTP headroom -> large pre-gain, calibrated by sweep
#   - LRA 7.6 / crest ~14.4 dB -> 2nd MOST DYNAMIC source in the whole family
#     (after NE_SALJI 8.1); moderate glue, slow attack preserves transients
#   - DARK + ROLLED-OFF TOP (unlike Part 1): air -35.2 sits BELOW brilliance
#     -33.5 (Part 1's air was alive ABOVE brilliance). Darkest air band measured
#     in the family. HF lift weighted to the rolled-off brilliance/air with a
#     FULL broad air lift (+2.5), where Part 1 used only a measured air touch (+1.5).
#   - BASS-DOMINANT, CLEAN low end (bass -20.6 strongest, lowmid -21.9 below it,
#     subbass -22.6 modest) -> only a gentle low-mid clarity cut as gain insurance;
#     NO bass boost (bass already strongest; boosting risks boom under big gain).
#   - DC offset -0.000163 -> corrected with dcshift=+0.000163 (re-enabled, non-negligible)
#   - min phase correlation -0.498 -> FAILS mono safety -> WIDENING SKIPPED (m=1.0),
#     stage retained in architecture, only headroom prep applied
#   - native 48 kHz preserved end-to-end (oversample 4x = 192 kHz, soxr precision 28)
#   - dedicated lower-ceiling MP3 source (E2). Note: this source reconstructs GENTLY
#     in libmp3lame -> ceiling 0.82 already gives MP3 -1.4 dBTP (Part 1 needed 0.77).
#
# CALIBRATION (empirical sweeps, not the shortcut formula):
#   pre-gain: end-of-D = -19.6 LUFS; shortcut predicted +9.6 dB (UNDER-SHOT by 0.9).
#     Sweep @ ceiling 0.85: +10.5=-10.0, +11.5=-9.5, +12.0=-9.2, +12.5=-9.0.
#     -> LOCKED +10.5 dB -> -10.0 LUFS / -1.4 dBTP / LRA 5.0.
#   MP3 ceiling sweep @ +10.5: 0.82=-1.4 dBTP (PASS), 0.80=-1.7, 0.78=-1.9, 0.77=-2.0.
#     -> LOCKED 0.82 -> MP3 -1.4 dBTP / -10.1 LUFS (matches WAV, passes <= -1.0).
#
# Usage: bash master_pipeline_ATTSS2.sh <source.wav> <output_name> <project_dir>
# ============================================================
set -e

SOURCE="${1:-source/All_the_Things_She_Said_Hardcore_Pop_2.wav}"
NAME="${2:-All_the_Things_She_Said_Hardcore_Pop_2}"
PROJECT_DIR="${3:-.}"

# --- Tunable parameters (calibrated for THIS source) ---
PREGAIN_DB="10.5"      # CALIBRATED: +10.5 -> -10.0 LUFS (sweep: 10.5=-10.0, 11.5=-9.5, 12.5=-9.0)
LIMIT_LOSSLESS="0.85"  # oversampled ceiling for WAV masters  (-> -1.4 dBTP final)
LIMIT_MP3="0.82"       # CALIBRATED: -> MP3 -1.4 dBTP / -10.1 LUFS (0.82 PASS; gentler than Part 1's 0.77)
OS_RATE="192000"       # 4x oversample of 48 kHz
NATIVE_RATE="48000"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT"
mkdir -p "$OUT"

echo ">>> Source: $SOURCE  (native ${NATIVE_RATE} Hz)"

# --- STAGE A: Headroom + DC removal + subsonic HPF ---
echo "[A] Headroom (-6dB), DC removal (+0.000163), HPF 25Hz/12dB"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-6dB,dcshift=0.000163,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (dark + ROLLED-OFF top, bass-dominant profile) ---
# -0.8dB @ 220Hz Q1.1 -> gentle low-mid clarity insurance under big make-up gain
#                        (lighter than Part 1's -1.0; lowmid here is cleaner vs bass)
# +1.2dB @ 3.2k  Q1.2 -> presence lift (recessed -30.4, but LESS than Part 1's -32.1
#                        -> slightly under Part 1's +1.5)
# +1.5dB @ 6k    Q1.0 -> brilliance/definition (recessed -33.5, MORE than Part 1's -32.1
#                        -> above Part 1's +1.0)
# +2.5dB @ 11k   Q0.7 -> FULL broad air lift: this top genuinely rolls off (air -35.2
#                        below brilliance) -> dark-top family treatment, not Part 1's
#                        measured +1.5 (Part 1's air was alive)
# (NO low-end boost: bass -20.6 already strongest; boosting risks boom under +10.5 dB)
echo "[B] Parametric EQ (dark + rolled-off top profile)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=220:t=q:w=1.1:g=-0.8,\
equalizer=f=3200:t=q:w=1.2:g=1.2,\
equalizer=f=6000:t=q:w=1.0:g=1.5,\
equalizer=f=11000:t=q:w=0.7:g=2.5" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (glue) ---
# Source is the 2nd most dynamic in the family (LRA 7.6, crest ~14.4) -> moderate glue,
# 25 ms attack keeps transient punch; matches the direct sibling Part 1's glue.
echo "[C] Bus compression / glue (1.8:1 @ -18dB, 25ms attack)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-18dB:ratio=1.8:attack=25:release=200:makeup=1.5:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Stereo stage (WIDENING SKIPPED) + headroom prep ---
# min phase correlation -0.498 FAILS mono safety -> no widening (m=1.0).
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
