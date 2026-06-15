#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — Under_My_Spell (Hardcore Pop)
# Target: -10 LUFS integrated, <= -1.0 dBTP true peak
# Source: 16-bit PCM, 48 kHz, stereo, 3:09.92
# Chain: prep -> EQ -> comp -> (no widen) -> 4x oversampled limit
# Re-tuned from Hymn_to_Osiris template per pre-master diagnostic:
#   - quiet (-14.2 LUFS) + clean-peaked (-3.26 dBTP) source
#   - very strong, nearly-tied sub+bass (-20.4 / -20.7 dB)
#   - scooped midrange (1-2 kHz at -30.7), NO presence scoop
#   - tightest dynamics yet (LRA 3.5) -> gentlest compression
#   - mono safety: skip widening (min phase corr -0.589)
#   - headline move: open the dark top (presence -> air) without
#     fighting the intended bass weight
# ============================================================
set -e

SOURCE="${1:-source/Under_My_Spell_-_Hardcore_Pop.wav}"
NAME="${2:-Under_My_Spell}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE"

# --- STAGE A: Headroom + subsonic HPF (DC shift skipped: 0.000183 negligible) ---
echo "[A] Headroom (-3dB), HPF 25Hz/12dB  (DC shift skipped)"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-3dB,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (top-focused; no low-end EQ) ---
# +0.8dB @ 3.5k Q1.2 -> lift presence / vocal clarity
# +0.5dB @ 7k   Q1.0 -> brilliance bridge (sparkle, avoid harsh 4-6k)
# +1.5dB @ 12k  Q0.7 -> broad air lift (open the dark top)
# (no low-end EQ: sub+bass already strongest; preserve intended weight)
echo "[B] Parametric EQ (presence + brilliance bridge + air)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=3500:t=q:w=1.2:g=0.8,\
equalizer=f=7000:t=q:w=1.0:g=0.5,\
equalizer=f=12000:t=q:w=0.7:g=1.5" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (gentlest glue) ---
# th -14dB, ratio 1.4, attack 25ms, release 200ms, knee 4, makeup 1.0
# Gentlest of any track to date: source LRA is only 3.5 LU (already
# heavily compressed) -> minimal glue, preserve remaining dynamics.
# makeup=1.0 is the acompressor filter minimum (valid range 1-64).
echo "[C] Bus compression (gentle glue)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-14dB:ratio=1.4:attack=25:release=200:makeup=1.0:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Headroom prep (NO widening) ---
# extrastereo SKIPPED: min phase correlation -0.589 -> widening risks mono fold-down
echo "[D] Headroom prep (-3dB)  [stereo widening skipped for mono safety]"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4x oversampled true-peak limiting ---
# +10.5dB pre-gain -> upsample 4x (48->192kHz) soxr -> alimiter @0.85 (-1.4dBFS) -> downsample
# Pre-gain locked empirically: stage D measured -20.3 LUFS; +10.5 dB lands -10.0 LUFS exactly.
echo "[E] 4x oversampled true-peak limiting (+10.5dB / 192kHz / -1.0 dBTP)"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+10.5dB,\
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
        -af "ebur128=peak=true" -f null - 2>&1 | \
        grep -A 3 -E "Integrated loudness:|Loudness range:|True peak:" | \
        grep -E "I:|LRA:|Peak:"
done

echo ""
echo "Done. Deliverables in: $OUT/"
