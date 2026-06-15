#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — Kkodeks_drumovski_-_Cofi_Kkasper
# Source: 48 kHz / 16-bit PCM stereo
# Target: -10 LUFS integrated, ≤ -1.0 dBTP true peak
# Chain : prep → EQ → comp (gentle) → headroom prep (no widening) → 4x oversampled limit @ 192kHz
#
# Tuning rationale (vs. zeldi_bumbap_15_05 template):
#   - Source is QUIET (-15.1 LUFS) instead of LOUD: lighter headroom prep (-3 vs -6)
#   - LRA already small (3.9 LU): lighter compression (ratio 1.5, threshold -14)
#   - Stereo phase min -0.823: SKIP widening (would risk mono compatibility)
#   - Spectrum dark in top: bigger air lift (+2 @ 12k), added brilliance bell (+0.6 @ 6k)
#   - No low-mid mud build-up: drop the 200 Hz cut, drop the 80 Hz bass reinforce
#   - Source native 48 kHz: oversample target = 192 kHz (4×); 48 kHz kept end-to-end
# ============================================================
set -e

SOURCE="${1:-source/Kkodeks_drumovski_-_Cofi_Kkasper.wav}"
NAME="${2:-Kkodeks_drumovski_-_Cofi_Kkasper}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE"

# --- STAGE A: Headroom + subsonic HPF (no DC shift; source DC offset already negligible) ---
echo "[A] Headroom -3dB + HPF 25Hz/12dB"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-3dB,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ ---
# +0.8dB @ 3.5k Q1.5  → presence (track sits dark)
# +0.6dB @ 6k   Q1.2  → brilliance fill
# +2.0dB @ 12k  Q0.7  → broad air lift (compensate ~12.6 dB downhill slope)
echo "[B] Parametric EQ (presence + brilliance + air)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=3500:t=q:w=1.5:g=0.8,\
equalizer=f=6000:t=q:w=1.2:g=0.6,\
equalizer=f=12000:t=q:w=0.7:g=2.0" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (very gentle — LRA already 3.9 LU) ---
# threshold -14dB, ratio 1.5, attack 25ms, release 200ms, knee 4, makeup 1.0
echo "[C] Bus compression (gentle glue)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-14dB:ratio=1.5:attack=25:release=200:makeup=1.0:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Headroom prep ONLY (no stereo widening — min corr -0.823 in source) ---
echo "[D] Headroom prep -3dB (NO widening — mono-safety)"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4× oversampled true-peak limiting ---
# +12dB pre-gain → upsample 48k→192k (soxr p28) → alimiter @ 0.85 (-1.4 dBFS) → downsample
echo "[E] 4× oversampled limiting (+12dB / 192 kHz / -1.4 dBFS ceiling)"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+12.0dB,\
aresample=192000:resampler=soxr:precision=28,\
alimiter=limit=0.85:attack=2:release=80:level=disabled,\
aresample=48000:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05_limited.wav" 2>/dev/null

# --- DELIVERABLES ---
echo "[F1] 32-bit float WAV @ 48 kHz (archival)"
cp "$INT/05_limited.wav" "$OUT/${NAME}_MASTER_32f.wav"

echo "[F2] 16-bit WAV @ 48 kHz with TPDF dither (distribution)"
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
    echo ""
    echo "$(basename "$f")"
    ffmpeg -hide_banner -nostats -i "$f" \
        -af "ebur128=peak=true:framelog=quiet" -f null - 2>&1 | \
        grep -E "I:|LRA:|Peak:" | head -3
done

echo ""
echo "Done. Deliverables in: $OUT/"
