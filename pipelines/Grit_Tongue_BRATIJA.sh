#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — Grit_Tongue_BRATIJA_26
# Target: -10 LUFS integrated, <= -1.0 dBTP true peak
# Source: 16-bit PCM, 48 kHz, stereo, 1:02.24
# Chain: prep(+DC) -> EQ -> comp -> (no widen) -> 4x oversampled limit
# Re-tuned from 10_outta_10 template per pre-master diagnostic.
#
# WHY THIS TRACK BREAKS FROM THE HARDCORE-POP FAMILY:
#   - QUIETEST of the recent batch (-15.7 LUFS) -> largest make-up
#     gain of the batch (~+5.7 dB integrated)
#   - MOST DYNAMIC of the batch (LRA 5.6, crest ~12.4 dB) -> real
#     dynamics to preserve; can take slightly firmer glue (R 1.6)
#   - very clean-peaked (-4.8 dBTP) -> ample headroom, no IS-clipping
#   - SUB-LED low end with a STEEP falloff (sub -21.1 strongest, bass
#     -23.0, lowmid -26.4) -> NOT the nearly-tied family low end, so a
#     small low-mid SUPPORT boost is safe (family forbade low-end EQ)
#   - GENUINE MID SCOOP at 500Hz-1k (-31.7 floor) -> new: a broad mid
#     fill at ~700 Hz (family tracks had no mid work)
#   - dark top as usual (sub->air slope 13.5 dB) -> presence+air lift
#   - DC offset +0.000418 (largest of any source) -> DC-SHIFT STAGE
#     RE-ENABLED here (conditionally skipped on the negligible-DC
#     family tracks; this is the threshold case it exists for)
#   - mono safety: skip widening (min phase corr -0.398, mildest yet
#     but still negative)
# ============================================================
set -e

SOURCE="${1:-source/Grit_Tongue_BRATIJA_26.wav}"
NAME="${2:-Grit_Tongue_BRATIJA}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE"

# --- STAGE A: Headroom + DC removal + subsonic HPF ---
# DC shift RE-ENABLED: source DC +0.000418 is the largest of any track;
# dcshift=-0.000418 brings it to ~-0.000009 (effectively zero).
echo "[A] Headroom (-3dB), DC removal (+0.000418), HPF 25Hz/12dB"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-3dB,dcshift=-0.000418,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (low-mid support + mid fill + top lift) ---
# +1.0dB @ 200 Q1.0  -> low-mid support (low end falls off steeply, not tied)
# +1.2dB @ 700 Q0.9  -> fill the genuine 500Hz-1k mid scoop (NEW for this track)
# +0.8dB @ 3.5k Q1.2 -> presence / vocal clarity
# +0.5dB @ 7k   Q1.0 -> brilliance bridge (sparkle, avoid harsh 4-6k)
# +1.7dB @ 12k  Q0.7 -> broad air lift (open the dark top)
echo "[B] Parametric EQ (lowmid support + mid fill + presence + brilliance + air)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=200:t=q:w=1.0:g=1.0,\
equalizer=f=700:t=q:w=0.9:g=1.2,\
equalizer=f=3500:t=q:w=1.2:g=0.8,\
equalizer=f=7000:t=q:w=1.0:g=0.5,\
equalizer=f=12000:t=q:w=0.7:g=1.7" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (firmer glue than the squashed family) ---
# th -15dB, ratio 1.6, attack 25ms, release 200ms, knee 4, makeup 1.2
# Source LRA 5.6 / crest 12.4 dB is the MOST dynamic of the batch, so this
# steps back toward the zeldi/Hymn R1.6 region for real glue without
# over-squashing (the family used R1.4-1.5 for LRA 3.5-4.1 sources).
echo "[C] Bus compression (glue, R1.6)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-15dB:ratio=1.6:attack=25:release=200:makeup=1.2:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Headroom prep (NO widening) ---
# extrastereo SKIPPED: min phase correlation -0.398 (mildest anti-phase of
# the batch, but still negative) -> widening would risk mono fold-down.
echo "[D] Headroom prep (-3dB)  [stereo widening skipped for mono safety]"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4x oversampled true-peak limiting ---
# +10.6dB pre-gain -> upsample 4x (48->192kHz) soxr -> alimiter @0.85 (-1.4dBFS) -> downsample
# Pre-gain locked empirically by sweep: stage D measured -19.9 LUFS, but this
# more-dynamic source loses more to the limiter than the squashed family, so
# the naive "target - stageD" (+9.9) under-shot to -10.3. Swept 9.9->11.0;
# +10.6 dB lands -9.9 LUFS (within 0.1 of target, on the loud side).
echo "[E] 4x oversampled true-peak limiting (+10.6dB / 192kHz / -1.0 dBTP)"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+10.6dB,\
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
