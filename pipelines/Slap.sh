#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — Slap (Hardcore Pop)
# Target: -10 LUFS integrated, <= -1.0 dBTP true peak
# Source: 16-bit PCM, 48 kHz, stereo, 3:07.28
# Chain: prep -> EQ -> comp -> (no widen) -> 4x oversampled limit
# Re-tuned from 10_outta_10 template per pre-master diagnostic:
#   - quiet (-13.5 LUFS) + clean-peaked (-3.1 dBTP) source
#   - very strong, nearly-tied low end: sub -20.3 / bass -20.0 /
#     lowmid -22.4 -> bass-dominant, smooth descending slope
#   - NO presence scoop -> general clarity lift, not a fill
#   - dark top: bass->air slope ~12.9 dB (between UMS 11.7 and
#     10_outta_10 14.0) -> interpolated air lift (+1.6 dB)
#   - TIGHTEST dynamics of the whole family (LRA 3.2) -> gentlest
#     compression tier (R 1.4, matches Under_My_Spell)
#   - mono safety: skip widening (min phase corr -0.356 -- the
#     LEAST anti-phase recent source, but still negative)
#   - headline move: open the dark top (presence -> air) without
#     fighting the intended bass weight; limiter tames the lows
# ============================================================
set -e

SOURCE="${1:-source/Slap_-_Hardcore_Pop.wav}"
NAME="${2:-Slap}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE"

# --- STAGE A: Headroom + subsonic HPF (DC shift skipped: 0.000229 negligible) ---
echo "[A] Headroom (-3dB), HPF 25Hz/12dB  (DC shift skipped)"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-3dB,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (top-focused; no low-end EQ) ---
# +0.8dB @ 3.5k Q1.2 -> lift presence / vocal clarity in a bass-heavy mix
# +0.5dB @ 7k   Q1.0 -> brilliance bridge (sparkle, avoid harsh 4-6k)
# +1.6dB @ 12k  Q0.7 -> broad air lift; interpolated between UMS (+1.5 @ air -32.0)
#                       and 10_outta_10 (+1.7 @ air -33.4) for this top (-32.9)
# (no low-end EQ: sub+bass+lowmid already strongest; preserve intended weight,
#  let the limiter gently tame the low end as on every prior master)
echo "[B] Parametric EQ (presence + brilliance bridge + air)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=3500:t=q:w=1.2:g=0.8,\
equalizer=f=7000:t=q:w=1.0:g=0.5,\
equalizer=f=12000:t=q:w=0.7:g=1.6" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (gentlest glue) ---
# th -14dB, ratio 1.4, attack 25ms, release 200ms, knee 4, makeup 1.0
# Gentlest tier: source LRA is only 3.2 LU (tightest of the family) and crest
# ~11.8 dB confirms an already heavily-limited source -> minimal glue, preserve
# what little dynamics remain. Matches Under_My_Spell (R 1.4).
# 25 ms attack preserves kick transients; 200 ms release musical pumping;
# makeup=1.0 is the acompressor filter minimum (valid range 1-64).
echo "[C] Bus compression (gentle glue)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-14dB:ratio=1.4:attack=25:release=200:makeup=1.0:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Headroom prep (NO widening) ---
# extrastereo SKIPPED: min phase correlation -0.356 -> still negative (brief
# out-of-phase moments). The least anti-phase recent source, but consistent
# family policy keeps widening off to guarantee mono fold-down.
echo "[D] Headroom prep (-3dB)  [stereo widening skipped for mono safety]"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4x oversampled true-peak limiting ---
# +9.8dB pre-gain -> upsample 4x (48->192kHz) soxr -> alimiter @0.85 (-1.4dBFS) -> downsample
# Pre-gain locked empirically: stage D measured -19.7 LUFS; +9.8 dB lands -10.0 LUFS exactly.
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
        grep -A 14 "Summary:" | grep -E "I:|LRA:|Peak:" | head -3
done

echo ""
echo "Done. Deliverables in: $OUT/"
