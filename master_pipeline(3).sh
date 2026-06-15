#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — Real_Love x My_Posh_Princess (Mashup, Hardcore Pop)
# Target: -10 LUFS integrated, <= -1.0 dBTP true peak (16-bit WAV canonical)
# Source: 16-bit PCM, 48 kHz, stereo, 4:34.36
# Chain: prep -> EQ -> comp -> (no widen) -> 4x oversampled limit
# Re-tuned from NE_SALJI_MI_PPISMO link per pre-master diagnostic. This source
# is the SECOND bright-top outlier (after Try_Aggain) -> preserve-and-polish:
#   - QUIETEST source of the whole family (-16.3 LUFS) -> LARGEST make-up
#     gain to date (+12.5 dB pre-gain; previous high was +12.0)
#   - clean-peaked (-4.1 dBTP) -> no inter-sample clipping in source
#   - HIGHEST crest of the family (~15.6 dB) -> most dynamic/punchy/least-
#     limited source yet, despite a tight LRA 3.4 LU -> gentlest comp tier
#   - BRIGHT, OPEN TOP with a SCOOPED MID: brilliance -29.4 and air -28.7 sit
#     nearly as strong as bass (-26.0); the 250 Hz-4 kHz region (-31.6/-31.8)
#     is the most recessed. bass->air slope only ~2.7 dB (vs family 11.7-14.3;
#     Try_Aggain 6.5). The family's "+1.5-1.9 dB air lift to open a dark top"
#     would OVER-BRIGHTEN here -> INVERTED EQ: gentle scoop-fill at the mid
#     center + a whisper of ultra sheen on the only recessed top band.
#   - low end modest & clean (bass -26.0 strongest, descending, no mud/boom)
#     -> no low-end EQ; the limiter gently tames it under the big make-up gain
#   - mono safety: skip widening (min phase corr -0.196 -- the LEAST anti-phase
#     source ever recorded, but still negative -> consistent family policy)
# ============================================================
set -e

SOURCE="${1:-source/Real_Love_x_Posh_Princess_Mashup.wav}"
NAME="${2:-Real_Love_x_Posh_Princess}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE"

# --- STAGE A: Headroom + subsonic HPF (DC shift skipped: -0.000093 negligible) ---
echo "[A] Headroom (-3dB), HPF 25Hz/12dB  (DC shift skipped)"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-3dB,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (INVERTED vs dark-top family: source already bright) ---
# +0.7dB @ 3.0k Q1.0 -> gentle fill of the scooped presence/upper-mid center
#                       (1-4 kHz all sit ~-31.6, recessed under the bright bands)
# NO 7k brilliance bridge: 4-8k (-29.4) is already one of the brightest bands
# NO broad 8-16k air lift: air (-28.7) is already the brightest top band
# +0.5dB @ 16k  Q0.9 -> whisper of sheen on the ONLY recessed top band
#                       (16k+ ultra at -39.0); tight Q to avoid bloating 8-16k
# NO low-end EQ: lows modest, clean & well-proportioned -> preserve weight
echo "[B] Parametric EQ (scoop-fill presence + whisper of ultra-air; top already open)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=3000:t=q:w=1.0:g=0.7,\
equalizer=f=16000:t=q:w=0.9:g=0.5" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (gentlest glue tier) ---
# th -14dB, ratio 1.4, attack 25ms, release 200ms, knee 4, makeup 1.0
# Gentlest tier (R 1.4, matches Slap/Under_My_Spell). LRA is only 3.4 LU
# (2nd tightest of the family) but crest is ~15.6 dB (the HIGHEST) -> the
# source is punchy/alive; over-compressing would flatten its defining
# transients. Light cohesion only; the limiter does the loudness work.
# 25 ms attack preserves kick transients; 200 ms release musical pumping;
# makeup=1.0 is the acompressor filter minimum (valid range 1-64).
echo "[C] Bus compression (gentle glue)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-14dB:ratio=1.4:attack=25:release=200:makeup=1.0:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Headroom prep (NO widening) ---
# extrastereo SKIPPED: min phase correlation -0.196 -> the LEAST anti-phase
# source on record, but still negative (brief out-of-phase moments). Consistent
# family policy keeps widening off to guarantee mono fold-down. Source is also
# the widest on average (mean +0.784).
echo "[D] Headroom prep (-3dB)  [stereo widening skipped for mono safety]"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4x oversampled true-peak limiting ---
# +12.5dB pre-gain -> upsample 4x (48->192kHz) soxr -> alimiter @0.85 (-1.4dBFS) -> downsample
# Pre-gain locked empirically: stage D measured -22.1 LUFS (lowest of the family).
# This high-crest source sheds ~0.7 dB integrated to limiter peak-reduction, so
# +12.5 dB lands -10.0 LUFS exactly. HIGHEST pre-gain of the family (prev +12.0).
echo "[E] 4x oversampled true-peak limiting (+12.5dB / 192kHz / -1.0 dBTP)"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+12.5dB,\
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
