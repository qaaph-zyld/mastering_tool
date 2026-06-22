#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — Try_Aggain (Hardcore Pop)
# Target: -10 LUFS integrated, <= -1.0 dBTP true peak (16-bit WAV canonical)
# Source: 16-bit PCM, 48 kHz, stereo, 2:32.32
# Chain: prep -> EQ -> comp -> (no widen) -> 4x oversampled limit
# Re-tuned from Slap template per pre-master diagnostic. This source
# BREAKS the hardcore-pop family pattern:
#   - quiet (-13.6 LUFS) + clean-peaked (-2.9 dBTP) source
#   - MOST macro-dynamic of the whole family (LRA 4.3) and HIGHEST
#     crest (~13.2 dB) -> least-limited, most "alive" source so far
#   - low end NOT dominant: sub/bass tied at -22.6 (quietest lows of
#     the family); lowmid -24.3 -> clean, well-proportioned
#   - TOP ALREADY OPEN: bass->air slope only ~6.5 dB (family was
#     11.7-14.3) -> brilliance (-28.8) even sits ABOVE presence (-29.0)
#   - INVERTED EQ: the family's headline "+1.5-1.8 dB air lift to open
#     a dark top" would OVER-BRIGHTEN here. Replaced with a gentle
#     presence touch + a whisper of ultra-air sheen on the only
#     recessed top band (16k+ at -38.5). Preserve & polish, don't open.
#   - mono safety: skip widening (min phase corr -0.326 -- least
#     anti-phase recent source, but still negative -> family policy)
# ============================================================
set -e

SOURCE="${1:-source/Try_Aggain_Hardcore_Pop_1.wav}"
NAME="${2:-Try_Aggain}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE"

# --- STAGE A: Headroom + subsonic HPF (DC shift skipped: 0.000231 negligible) ---
echo "[A] Headroom (-3dB), HPF 25Hz/12dB  (DC shift skipped)"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-3dB,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (INVERTED vs family: source already bright) ---
# +0.5dB @ 3.5k Q1.2 -> gentle presence/vocal clarity (HALF the family's lift)
# +0.6dB @ 15k  Q0.7 -> whisper of ultra-air sheen on the only recessed top
#                       band (16k+ at -38.5); a fraction of the family's +1.6
# NO 7k brilliance bridge: 4-8k (-28.8) is already the BRIGHTEST top region
# NO low-end EQ: sub/bass/lowmid clean & well-proportioned -> preserve weight
echo "[B] Parametric EQ (gentle presence + whisper of ultra-air; top already open)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=3500:t=q:w=1.2:g=0.5,\
equalizer=f=15000:t=q:w=0.7:g=0.6" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (gentle glue) ---
# th -14dB, ratio 1.5, attack 25ms, release 200ms, knee 4, makeup 1.0
# Gentle tier. LRA 4.3 is the MOST macro-dynamic of the family, so R 1.5
# (matching Hit_It / 10_outta_10) adds light cohesion to the most dynamic
# source while preserving the healthy ~13 dB crest. 25 ms attack preserves
# kick transients; 200 ms release musical pumping; makeup=1.0 filter minimum.
echo "[C] Bus compression (gentle glue)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-14dB:ratio=1.5:attack=25:release=200:makeup=1.0:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Headroom prep (NO widening) ---
# extrastereo SKIPPED: min phase correlation -0.326 -> still negative; family
# policy keeps widening off to guarantee mono fold-down.
echo "[D] Headroom prep (-3dB)  [stereo widening skipped for mono safety]"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4x oversampled true-peak limiting ---
# +10.2dB pre-gain -> upsample 4x (48->192kHz) soxr -> alimiter @0.85 (-1.4dBFS) -> downsample
# Pre-gain locked empirically: stage D measured -19.8 LUFS, but this dynamic a
# source loses ~0.3 dB integrated to peak reduction in the limiter, so +9.8
# landed -10.3; +10.2 lands -10.0 LUFS exactly.
echo "[E] 4x oversampled true-peak limiting (+10.2dB / 192kHz / -1.0 dBTP)"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+10.2dB,\
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
        grep -A 20 "Summary:" | grep -E "I:|LRA:|Peak:" | head -3
done

echo ""
echo "Done. Deliverables in: $OUT/"
