#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — MONSTAH_demo_1_gg
# Target: -10 LUFS integrated, <= -1.0 dBTP true peak (16-bit WAV canonical)
# Source: MP3 ~193 kbps, 48 kHz, stereo, 2:47.68  (FIRST LOSSY-ORIGIN track
#         in the active family — front-end adds an explicit decode stage)
# Chain: decode -> prep -> EQ -> comp -> (no widen) -> 4x oversampled limit
# Re-tuned from NE_SALJI_MI_PPISMO template per pre-master diagnostic.
#
# This source's closest sibling is Slap (squashed dark-top, sub-leaning):
#   - LOSSY ORIGIN: MP3 ~193 kbps. Decoded to 32-bit float WAV before any
#     processing. Treated as a finished mix; top-end lift kept conservative
#     because boosting air also amplifies MP3 HF quantisation artifacts.
#   - quiet (-13.9 LUFS) + clean-peaked (-2.26 dBTP)
#   - LRA 3.2 LU -> squashed (ties Slap as most-compressed in the family);
#     crest ~13.4 dB confirms a heavily-limited generative source
#   - sub-leaning, very even low end: sub -21.5 ~= bass -21.5; lowmid -23.4
#     descending cleanly -> no mud, no boom -> NO low-end EQ
#   - DARK top but MILDEST in family: bass->air slope ~11.6 dB; air -33.2
#     sits between Slap (-32.9) and 10o10 (-33.4) -> air lift +1.6 @ 12k
#   - presence -29.5 is the BEST-placed top of the dark cohort -> only a
#     light +0.7 @ 3.5k clarity lift needed
#   - mono safety: skip widening (min phase corr -0.609)
#   - headline move: open the (mild) dark top conservatively for a lossy
#     source; let the limiter do the loudness work
# ============================================================
set -e

SOURCE_MP3="${1:-source/MONSTAH_demo_1_gg.mp3}"
NAME="${2:-MONSTAH}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
SRC="${PROJECT_DIR}/source"
mkdir -p "$INT" "$OUT" "$SRC"

echo ">>> Source (MP3): $SOURCE_MP3"

# --- STAGE 0: Decode lossy source to 32-bit float WAV ---
# -map 0:a drops the embedded cover-art (mjpeg) stream; all internal
# processing is lossless float from here on.
DECODED="$SRC/${NAME}_demo_1_gg_decoded.wav"
echo "[0] Decode MP3 -> 32-bit float WAV (strip cover-art stream)"
ffmpeg -hide_banner -nostats -y -i "$SOURCE_MP3" \
    -map 0:a -c:a pcm_f32le "$DECODED" 2>/dev/null

# --- STAGE A: Headroom + subsonic HPF (DC shift skipped: 0.000288 negligible) ---
echo "[A] Headroom (-3dB), HPF 25Hz/12dB  (DC shift skipped)"
ffmpeg -hide_banner -nostats -y -i "$DECODED" \
    -af "volume=-3dB,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (top-focused; conservative for lossy origin) ---
# +0.7dB @ 3.5k Q1.2 -> light presence/clarity lift (presence -29.5 already
#                       the best-placed top in the dark cohort -> needs little)
# +0.5dB @ 7k   Q1.0 -> brilliance bridge (sparkle, avoid harsh 4-6k)
# +1.6dB @ 12k  Q0.7 -> air lift; air -33.2 sits between Slap(-32.9,+1.6) and
#                       10o10(-33.4,+1.7) -> +1.6 matches Slap. Held to the
#                       low side because a lossy source's HF carries codec
#                       artifacts that an air boost would also amplify.
# (no low-end EQ: even, sub-leaning, well-proportioned low end -> preserve)
echo "[B] Parametric EQ (light presence + brilliance bridge + conservative air)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=3500:t=q:w=1.2:g=0.7,\
equalizer=f=7000:t=q:w=1.0:g=0.5,\
equalizer=f=12000:t=q:w=0.7:g=1.6" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (gentle glue) ---
# th -14dB, ratio 1.5, attack 25ms, release 200ms, knee 4, makeup 1.0
# Lightest tier. LRA 3.2 (ties Slap, most-compressed in family) + crest
# ~13.4 dB -> source is already squashed; goal is cohesion only, not loudness.
echo "[C] Bus compression (gentle glue)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-14dB:ratio=1.5:attack=25:release=200:makeup=1.0:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Headroom prep (NO widening) ---
# extrastereo SKIPPED: min phase correlation -0.609 -> widening would break
# mono fold-down. Source already adequately wide (mean +0.677).
echo "[D] Headroom prep (-3dB)  [stereo widening skipped for mono safety]"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4x oversampled true-peak limiting ---
# +11.0dB pre-gain -> upsample 4x (48->192kHz) soxr -> alimiter @0.85 (-1.4dBFS) -> downsample
# Pre-gain locked by 3-value bracket sweep (then extended): stage D measured
# -20.2 LUFS. This squashed/flat-topped source drives the limiter into near-
# constant gain reduction, shedding ~1.0 dB integrated, so the naive +10.2
# landed only -10.5. Sweep: +10.4=-10.4, +10.6=-10.2, +10.8=-10.1,
# +11.0=-10.0 exactly. +11.0 selected (most transient-preserving compliant).
echo "[E] 4x oversampled true-peak limiting (+11.0dB / 192kHz / -1.0 dBTP)"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+11.0dB,\
aresample=192000:resampler=soxr:precision=28,\
alimiter=limit=0.85:attack=2:release=80:level=disabled,\
aresample=48000:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05_limited.wav" 2>/dev/null

# --- STAGE E2: Lower-ceiling limiter pass for the MP3 encoding path ---
# libmp3lame generates reconstruction peaks INDEPENDENT of the WAV ceiling,
# so the WAV's -1.4 dBFS alone cannot guarantee MP3 true-peak compliance.
# A dedicated lower ceiling (0.80 = -1.94 dBFS) is applied before encoding.
# This is doubly important here because the SOURCE is already lossy: encoding
# a decoded-MP3 back to MP3 can compound HF reconstruction overshoot.
echo "[E2] Lower-ceiling limiter pass for MP3 path (-1.94 dBFS)"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+11.0dB,\
aresample=192000:resampler=soxr:precision=28,\
alimiter=limit=0.80:attack=2:release=80:level=disabled,\
aresample=48000:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05b_limited_mp3path.wav" 2>/dev/null

# --- DELIVERABLES ---
echo "[F] Deliverable 1: 32-bit float WAV (archival)"
cp "$INT/05_limited.wav" "$OUT/${NAME}_MASTER_32f.wav"

echo "[F] Deliverable 2: 16-bit WAV with TPDF dither"
ffmpeg -hide_banner -nostats -y -i "$INT/05_limited.wav" \
    -af "aresample=osf=s16:dither_method=triangular_hp" \
    -c:a pcm_s16le "$OUT/${NAME}_MASTER_16.wav" 2>/dev/null

echo "[F] Deliverable 3: 320 kbps CBR MP3 (joint stereo) from the E2 lower-ceiling path"
ffmpeg -hide_banner -nostats -y -i "$INT/05b_limited_mp3path.wav" \
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
