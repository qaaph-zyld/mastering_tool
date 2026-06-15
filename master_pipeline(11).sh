#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — Hymn_to_Osiris (Hardcore Pop)
# Target: -10 LUFS integrated, <= -1.0 dBTP true peak
# Source: 16-bit PCM, 48 kHz, stereo, 3:56
# Chain: prep -> EQ -> comp -> (no widen) -> 4x oversampled limit
# Re-tuned from cofi_kkasper template per pre-master diagnostic:
#   - quiet (-14.5 LUFS) + clean-peaked (-3.4 dBTP) source
#   - headline fix: 2-4 kHz presence scoop
#   - mono safety: skip widening (min phase corr -0.437)
# ============================================================
set -e

SOURCE="${1:-source/Hymn_to_Osiris-_Hardcore_Pop.wav}"
NAME="${2:-Hymn_to_Osiris}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE"

# --- STAGE A: Headroom + subsonic HPF (DC shift skipped: -0.00013 negligible) ---
echo "[A] Headroom (-3dB), HPF 25Hz/12dB  (DC shift skipped)"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-3dB,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ ---
# +1.2dB @ 3k  Q1.2  -> fill 2-4k presence scoop (headline fix)
# +0.5dB @ 6k  Q1.0  -> gentle brilliance bridge (avoid 5-7k notch)
# +1.2dB @ 12k Q0.7  -> broad air lift (openness)
# (no low-end EQ: 60-120 bass already strongest, lowmid clean)
echo "[B] Parametric EQ (presence + brilliance bridge + air)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=3000:t=q:w=1.2:g=1.2,\
equalizer=f=6000:t=q:w=1.0:g=0.5,\
equalizer=f=12000:t=q:w=0.7:g=1.2" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (glue) ---
# th -16dB, ratio 1.6, attack 20ms, release 180ms, knee 4, makeup 1.2
# Between the two references: firmer than cofi (LRA was 3.9) since this
# source has LRA 5.2; 20ms attack preserves kick transients (hardcore pop punch)
echo "[C] Bus compression (glue)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-16dB:ratio=1.6:attack=20:release=180:makeup=1.2:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Headroom prep (NO widening) ---
# extrastereo SKIPPED: min phase correlation -0.437 -> widening risks mono fold-down
echo "[D] Headroom prep (-3dB)  [stereo widening skipped for mono safety]"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4x oversampled true-peak limiting ---
# +9.8dB pre-gain -> upsample 4x (48->192kHz) soxr -> alimiter @0.85 (-1.4dBFS) -> downsample
echo "[E] 4x oversampled true-peak limiting (+9.8dB / 192kHz / -1.0 dBTP)"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+9.8dB,\
aresample=192000:resampler=soxr:precision=28,\
alimiter=limit=0.85:attack=2:release=80:level=disabled,\
aresample=48000:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05_limited.wav" 2>/dev/null

# --- DELIVERABLES ---
echo "[F] Deliverable 1: 32-bit float WAV (archival)"
cp "$INT/05_limited.wav" "$OUT/${NAME}_MASTER_32f.wav"

echo "[F] Deliverable 2: 16-bit WAV with TPDF dither"
ffmpeg -hide_banner -nostats -y -i "$INT/05_limited.wav" \
    -af "aresample=osf=s16:dither_method=triangular_hp" \
    -c:a pcm_s16le "$OUT/${NAME}_MASTER_16.wav" 2>/dev/null

echo "[F] Deliverable 3: 320 kbps CBR MP3 (joint stereo)"
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
