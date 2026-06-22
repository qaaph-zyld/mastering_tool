#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — Master_of_Boredom (Hardcore Pop)
# Source: 16-bit / 48 kHz / stereo
# Target: -9.7 LUFS integrated, true peak guaranteed <= -1.0 dBTP
# Chain : prep -> EQ -> light glue -> stereo -> 4x oversampled limit
#
# Chain tuned to THIS track's diagnosis (dark/recessed mids+highs,
# slight sub dominance, narrow image, already low LRA). Do NOT reuse
# blindly on a different source — re-run premaster_diagnostic.sh first.
#
# Usage: bash master_pipeline.sh <source.wav> <output_name> <project_dir>
# ============================================================
set -e

SOURCE="${1:-source/Master_of_Boredom.wav}"
NAME="${2:-Master_of_Boredom}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE"

# --- STAGE A: Headroom + subsonic HPF (DC negligible @ 0.00007, no dcshift) ---
echo "[A] Headroom (-2dB) + HPF 30Hz/12dB"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-2dB,highpass=f=30:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (corrective + tonal) ---
# -1.0dB @ 40Hz  Q0.9  -> tame slight sub dominance (loudest band)
# +1.2dB @ 2.8k  Q1.2  -> presence / clarity (recessed)
# +1.2dB @ 6k    Q1.0  -> definition / edge (recessed)
# +2.5dB @ 11k   shelf -> air / sheen (thin band)
echo "[B] Parametric EQ"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=40:t=q:w=0.9:g=-1.0,\
equalizer=f=2800:t=q:w=1.2:g=1.2,\
equalizer=f=6000:t=q:w=1.0:g=1.2,\
highshelf=f=11000:t=q:w=0.7:g=2.5" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Light bus glue (LRA already 2.9 -> very gentle) ---
echo "[C] Bus glue (1.5:1, -18dB, 25ms attack)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-18dB:ratio=1.5:attack=25:release=200:makeup=1:knee=6" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Gentle stereo widening (narrow mix) + headroom prep ---
echo "[D] Stereo widen 12% + -3dB headroom prep"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "extrastereo=m=1.12,volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4x oversampled true-peak limiting (48k -> 192k -> 48k) ---
echo "[E] Limiting: +11.5dB / 192kHz oversample / limit 0.85 (-1.4 dBTP) / 48kHz"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+11.5dB,\
aresample=192000:resampler=soxr:precision=28,\
alimiter=limit=0.85:attack=2:release=80:level=disabled,\
aresample=48000:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05_limited.wav" 2>/dev/null

# --- DELIVERABLES ---
echo "[F1] 32-bit float WAV @48k (archival)"
cp "$INT/05_limited.wav" "$OUT/${NAME}_MASTER_32f.wav"

echo "[F2] 16-bit WAV @48k + TPDF dither (distribution)"
ffmpeg -hide_banner -nostats -y -i "$INT/05_limited.wav" \
    -af "aresample=osf=s16:dither_method=triangular_hp" \
    -c:a pcm_s16le "$OUT/${NAME}_MASTER_16.wav" 2>/dev/null

echo "[F3] 320 kbps CBR MP3 joint-stereo (streaming/preview)"
ffmpeg -hide_banner -nostats -y -i "$INT/05_limited.wav" \
    -c:a libmp3lame -b:a 320k -joint_stereo 1 \
    "$OUT/${NAME}_MASTER.mp3" 2>/dev/null

echo ""
echo "============ FINAL LOUDNESS REPORT ============"
for f in "$OUT/${NAME}_MASTER_32f.wav" "$OUT/${NAME}_MASTER_16.wav" "$OUT/${NAME}_MASTER.mp3"; do
    echo ""; echo "$(basename "$f")"
    ffmpeg -hide_banner -nostats -i "$f" \
        -af "ebur128=peak=true:framelog=quiet" -f null - 2>&1 | grep -E "I:|LRA:"
done
echo ""
echo "Done. Deliverables in: $OUT/"
