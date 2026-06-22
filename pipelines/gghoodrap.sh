#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline (44.1 kHz native) — gghoodrap
# Target: -10.0 LUFS integrated, <= -1.0 dBTP true peak (ALL deliverables)
# Chain: prep -> EQ -> light glue -> stereo(NEUTRAL) -> 4x oversampled limit (176.4 kHz)
#
# TUNED FOR THIS SOURCE (VERY LOUD, EXTREME OVERS, BASS-DOMINANT, DARK-TOP, PHASE-RISKY):
#   - source is -7.9 LUFS (LOUDER than the -10 target) with peaks at +7.9 dBFS
#     (Max 2.49 linear). peak count = 2 samples/ch -> transient OVERSHOOT in float,
#     NOT flat-top clipping -> recovered cleanly by gain-staging (no adeclip).
#   - STAGE A DEVIATION: headroom prep deepened to -10 dB (vs the usual -6) because
#     -6 would leave peaks at +1.9 dBFS (still over 0); -10 brings them to -2.2 dBFS
#     so EQ and the compressor operate on a sane-level signal. Documented deviation.
#   - heavily bass-dominant (sub/bass ~-16) with dark recessed top (presence/
#     brilliance ~-26, air -28.5) -> preserve the genre-signature low end, control
#     low-mid mud, and lift the recessed presence/brilliance/air.
#   - LRA 4.4 -> light glue (1.5:1).
#   - min phase correlation -0.66 -> FAILS mono safety -> WIDENING SKIPPED (m=1.00).
#   - DC -0.0013 removed by the 25 Hz subsonic HPF (dcshift gated; bass preserved).
#   - dedicated lower-ceiling MP3 source (E2) for lossy true-peak safety.
#
# CALIBRATION (empirical bracketing — shortcut under-shoots):
#   stage-D = -22.0 LUFS; shortcut pre-gain +12.0 -> measured -10.4 (under)
#   sweep: 12.0=-10.4, 12.5=-10.1, 12.6=-10.0, 12.8=-9.9, 13.1=-9.7, 13.5=-9.5
#   LOCKED PREGAIN = +12.6 dB -> -10.0 LUFS, WAV -1.4 dBTP
#   MP3 ceiling @ +12.6: 0.84=-1.4 dBTP (pass, on-target), 0.82=-1.6, 0.80=-1.8
#   LOCKED MP3 ceiling = 0.84 -> MP3 -1.4 dBTP, -10.0 LUFS
#
# Usage: bash master_pipeline_gghoodrap.sh <source.wav> <output_name> <project_dir>
# ============================================================
set -e

SOURCE="${1:-source/gghoodrap.wav}"
NAME="${2:-gghoodrap}"
PROJECT_DIR="${3:-.}"

# --- Tunable parameters (calibrated for THIS source) ---
PREP_DB="-10"          # DEVIATION: deeper headroom for +7.9 dBFS overs (usual -6)
PREGAIN_DB="12.6"      # CALIBRATED via bracketing sweep -> -10.0 LUFS
LIMIT_LOSSLESS="0.85"  # oversampled ceiling for WAV masters  (-> WAV -1.4 dBTP)
LIMIT_MP3="0.84"       # CALIBRATED for MP3 lossy true-peak safety (-> MP3 -1.4 dBTP)
OS_RATE="176400"       # 4x oversample of 44.1 kHz
NATIVE_RATE="44100"
DCSHIFT="0.0"          # GATED: DC -0.0013 removed by 25Hz HPF instead

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT"; mkdir -p "$OUT"

echo ">>> Source: $SOURCE  (native ${NATIVE_RATE} Hz)"

# --- STAGE A: deep headroom (hot source) + DC removal (gated) + subsonic HPF ---
echo "[A] Headroom (${PREP_DB}dB, deep for overs), DC via HPF, HPF 25Hz/12dB"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=${PREP_DB}dB,dcshift=${DCSHIFT},highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (bass-dominant, dark-top rap) ---
# -1.0dB @ 250Hz Q1.1 -> low-mid mud control (so master isn't congested when limited)
# +1.5dB @ 3k    Q1.0 -> presence / vocal intelligibility (recessed)
# +1.5dB @ 6k    Q1.0 -> brilliance / consonant definition (dark top)
# +1.5dB @ 11k   Q0.7 -> broad air lift (dark top)
# (sub/bass left intact -> genre signature)
echo "[B] Parametric EQ (bass-dominant, dark-top)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=250:t=q:w=1.1:g=-1.0,\
equalizer=f=3000:t=q:w=1.0:g=1.5,\
equalizer=f=6000:t=q:w=1.0:g=1.5,\
equalizer=f=11000:t=q:w=0.7:g=1.5" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (light glue) ---
echo "[C] Bus compression / glue (1.5:1 @ -18dB, 25ms attack)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-18dB:ratio=1.5:attack=25:release=200:makeup=1:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Stereo stage (WIDENING SKIPPED) + headroom prep ---
echo "[D] Stereo stage: WIDENING SKIPPED (m=1.00, phase-risky) + headroom prep (-3dB)"
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
    echo ""; echo "$(basename "$f")"
    ffmpeg -hide_banner -nostats -i "$f" \
        -af "ebur128=peak=true:framelog=quiet" -f null - 2>&1 | tail -14 | grep -E "I:|LRA:|Peak:"
done
echo ""
echo "Done. Deliverables in: $OUT/"
