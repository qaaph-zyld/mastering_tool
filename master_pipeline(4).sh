#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — NE_SALJI_MI_PPISMO (Hardcore Pop)
# Target: -10 LUFS integrated, <= -1.0 dBTP true peak (16-bit WAV canonical)
# Source: 16-bit PCM, 48 kHz, stereo, 4:41.44
# Chain: prep -> EQ -> comp -> (no widen) -> 4x oversampled limit
# Re-tuned from Try_Aggain link per pre-master diagnostic. This source
# RETURNS to the family's standard dark-top profile (Try_Aggain was the
# bright outlier), but is the MOST DYNAMIC source of the whole family:
#   - quiet (-14.8 LUFS) + clean-peaked (-3.6 dBTP) source
#   - LRA 8.1 LU + crest ~13.3 dB -> MOST macro-dynamic / least-limited
#     / most "alive" source to date (next closest: zeldi LRA 6.5)
#   - low end NOT dominant: subbass -24.2 is the QUIETEST band of the
#     family; bass -22.7 modest; clean descending slope, no mud/boom
#   - DARK top: bass->air slope ~12.2 dB; air -34.9 is the DARKEST air
#     band of the dark-top family -> standard "open the dark top" move,
#     air lift interpolated a touch above Hit_It (+1.8 @ air -34.0)
#   - mono safety: skip widening (min phase corr -0.820, 2nd most
#     anti-phase source ever, after Cofi -0.823)
#   - compression deliberately LIGHT (R 1.5 gentle tier) to PRESERVE the
#     unusually alive dynamics; the limiter does the loudness work and
#     naturally brings LRA under the <8 target (8.1 -> 6.4)
# ============================================================
set -e

SOURCE="${1:-source/NE_SALJI_MI_PPISMO_HITT_POP.wav}"
NAME="${2:-NE_SALJI_MI_PPISMO}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE"

# --- STAGE A: Headroom + subsonic HPF (DC shift skipped: 0.000292 negligible) ---
echo "[A] Headroom (-3dB), HPF 25Hz/12dB  (DC shift skipped)"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-3dB,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (top-focused; no low-end EQ) ---
# +0.8dB @ 3.5k Q1.2 -> lift recessed presence / vocal clarity (~7 dB under mids)
# +0.5dB @ 7k   Q1.0 -> brilliance bridge (sparkle, avoid harsh 4-6k)
# +1.9dB @ 12k  Q0.7 -> broad air lift; biggest of the bumpy family because the
#                       air band (-34.9) is the darkest yet (Hit_It -34.0 -> +1.8)
# (no low-end EQ: subbass is the quietest band, bass modest & clean -> preserve)
echo "[B] Parametric EQ (presence + brilliance bridge + biggest air)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=3500:t=q:w=1.2:g=0.8,\
equalizer=f=7000:t=q:w=1.0:g=0.5,\
equalizer=f=12000:t=q:w=0.7:g=1.9" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (gentle glue) ---
# th -14dB, ratio 1.5, attack 25ms, release 200ms, knee 4, makeup 1.0
# Gentle tier (R 1.5) DESPITE the large LRA 8.1: the goal is light cohesion,
# not loudness. Over-compressing the most alive source would flatten its
# defining feature. The limiter + natural range reduction bring LRA under the
# <8 target (8.1 source -> 7.7 after comp -> 6.4 final). makeup=1.0 = filter min.
echo "[C] Bus compression (gentle glue)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-14dB:ratio=1.5:attack=25:release=200:makeup=1.0:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Headroom prep (NO widening) ---
# extrastereo SKIPPED: min phase correlation -0.820 (2nd most anti-phase source
# on record) -> any widening would break mono fold-down.
echo "[D] Headroom prep (-3dB)  [stereo widening skipped for mono safety]"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4x oversampled true-peak limiting ---
# +12.0dB pre-gain -> upsample 4x (48->192kHz) soxr -> alimiter @0.85 (-1.4dBFS) -> downsample
# Pre-gain locked empirically: stage D measured -20.9 LUFS, but this very
# dynamic a source sheds ~1 dB integrated to limiter peak-reduction (slope
# ~0.5 LUFS per dB pre-gain), so +12.0 dB lands -10.0 LUFS exactly. This ties
# Cofi_Kkasper for the highest pre-gain of the family (quiet + dynamic source).
echo "[E] 4x oversampled true-peak limiting (+12.0dB / 192kHz / -1.0 dBTP)"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+12.0dB,\
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
