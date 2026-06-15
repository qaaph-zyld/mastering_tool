#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline (48 kHz native) — Keine_Zeit_zu_Verlieren
# Target: -10.0 LUFS integrated, <= -1.0 dBTP true peak (ALL deliverables)
# Chain: prep -> EQ -> glue comp -> stereo(NEUTRAL) -> 4x oversampled limit (192 kHz)
#
# TUNED FOR THIS SOURCE, as a deliberate delta from its sibling template
# (All_the_Things_She_Said_Hardcore_Pop_2 / "ATTSS2", mastered 2026-06-04):
#   - source -13.8 LUFS (quiet, 0.6 dB below ATTSS2's -13.2) with CLEAN -2.0 dBTP
#     headroom (1.3 dB more headroom than ATTSS2) -> large pre-gain, sweep-calibrated
#   - LRA 3.1 -> the TIGHTEST / least dynamic source in the whole family
#     (vs ATTSS2 7.6, NE_SALJI 8.1). Crest ~13.5 dB: transients survive, but macro
#     dynamics are already squashed -> GENTLE glue (1.4:1), slow 30 ms attack.
#   - DARK top, but EVENLY dark (not rolled-off like ATTSS2): presence -30.5,
#     brilliance -30.7, air -32.9. Brilliance is HEALTHIER here than ATTSS2 (-33.5)
#     -> LESS brilliance lift (+1.0 vs ATTSS2 +1.5). Air dark but not dead (-32.9
#     vs ATTSS2 -35.2) -> slightly LESS air (+2.0 vs ATTSS2 +2.5).
#   - BASS-DOMINANT, CLEAN low end (bass -20.5 strongest, lowmid -22.0, subbass -21.9)
#     -> only a gentle low-mid clarity cut as gain insurance; NO bass boost.
#   - DC offset +0.000313 -> corrected with dcshift=-0.000313 (re-enabled, larger than
#     ATTSS2's and OPPOSITE sign).
#   - min phase correlation -0.723 -> FAILS mono safety (more phase-risky than ATTSS2's
#     -0.498) -> WIDENING SKIPPED (m=1.0); stage retained, only headroom prep applied.
#     (Side RMS -32.6 vs Mid -15.6: largely centered content.)
#   - native 48 kHz preserved end-to-end (oversample 4x = 192 kHz, soxr precision 28)
#
# CALIBRATION (empirical sweeps):
#   pre-gain: end-of-D = -19.4 LUFS; shortcut predicted +9.4 dB.
#     Sweep @ ceiling 0.85: +9.4=-10.0, +10.0=-9.6, +10.5=-9.2, +11.0=-8.9.
#     -> shortcut MATCHED empirical here (source so tight the limiter does almost no
#        gain reduction -> loudness tracks pre-gain linearly).
#     -> LOCKED +9.4 dB -> -10.0 LUFS / -1.4 dBTP / LRA 2.4.
#   MP3 ceiling sweep @ +9.4: 0.85=-1.2 (already PASS), 0.82=-1.4, 0.80=-1.7, 0.78=-2.0.
#     -> LOCKED 0.82 -> MP3 -1.4 dBTP / -10.1 LUFS (matches WAV true peak, clean margin).
#
# Usage: bash master_pipeline_KZV.sh <source.wav> <output_name> <project_dir>
# ============================================================
set -e

SOURCE="${1:-source/Keine_Zeit_zu_Verlieren.wav}"
NAME="${2:-Keine_Zeit_zu_Verlieren}"
PROJECT_DIR="${3:-.}"

# --- Tunable parameters (calibrated for THIS source) ---
PREGAIN_DB="9.4"       # CALIBRATED: +9.4 -> -10.0 LUFS (sweep: 9.4=-10.0, 10.0=-9.6, 11.0=-8.9)
LIMIT_LOSSLESS="0.85"  # oversampled ceiling for WAV masters  (-> -1.4 dBTP final)
LIMIT_MP3="0.82"       # CALIBRATED: -> MP3 -1.4 dBTP / -10.1 LUFS (0.82; 0.85 also passed at -1.2)
OS_RATE="192000"       # 4x oversample of 48 kHz
NATIVE_RATE="48000"
DCSHIFT="-0.000313"    # cancels measured +0.000313 source DC offset

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT"
mkdir -p "$OUT"

echo ">>> Source: $SOURCE  (native ${NATIVE_RATE} Hz)"

# --- STAGE A: Headroom + DC removal + subsonic HPF ---
echo "[A] Headroom (-6dB), DC removal (${DCSHIFT}), HPF 25Hz/12dB"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-6dB,dcshift=${DCSHIFT},highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (dark + EVENLY-dark top, bass-dominant) ---
# -0.8dB @220Hz Q1.1 -> low-mid clarity insurance under big make-up gain
# +1.2dB @3.2k  Q1.2 -> presence lift (recessed -30.5; same band as ATTSS2)
# +1.0dB @6k    Q1.0 -> brilliance touch (only -30.7, healthier than ATTSS2 -> < its +1.5)
# +2.0dB @11k   Q0.7 -> broad air lift (air -32.9 dark but not dead -> < ATTSS2's +2.5)
# (NO low-end boost: bass -20.5 already strongest; boosting risks boom under +9.4 dB)
echo "[B] Parametric EQ (dark + evenly-dark top profile)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=220:t=q:w=1.1:g=-0.8,\
equalizer=f=3200:t=q:w=1.2:g=1.2,\
equalizer=f=6000:t=q:w=1.0:g=1.0,\
equalizer=f=11000:t=q:w=0.7:g=2.0" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (GENTLE glue) ---
# LRA 3.1 = tightest source in the family -> 1.4:1 only, 30 ms attack keeps the
# transient punch (crest ~13.5). Heavier glue would over-squash already-flat dynamics.
echo "[C] Bus compression / glue (1.4:1 @ -18dB, 30ms attack)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-18dB:ratio=1.4:attack=30:release=200:makeup=1.5:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Stereo stage (WIDENING SKIPPED) + headroom prep ---
# min phase correlation -0.723 FAILS mono safety -> no widening (m=1.0).
# Stage retained in architecture per framework; only -3dB headroom prep applied.
echo "[D] Stereo stage: WIDENING SKIPPED (m=1.0, phase-risky) + headroom prep (-3dB)"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "extrastereo=m=1.00,volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E1: 4x oversampled limiting for LOSSLESS masters ---
echo "[E1] 4x oversampled limit for WAV (+${PREGAIN_DB}dB / ${OS_RATE} / ceiling ${LIMIT_LOSSLESS})"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+${PREGAIN_DB}dB,\
aresample=${OS_RATE}:resampler=soxr:precision=28,\
alimiter=limit=${LIMIT_LOSSLESS}:attack=2:release=80:level=disabled,\
aresample=${NATIVE_RATE}:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05_limited.wav" 2>/dev/null

# --- STAGE E2: separate, lower-ceiling source for MP3 (lossy true-peak safety) ---
echo "[E2] 4x oversampled limit for MP3 source (ceiling ${LIMIT_MP3})"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+${PREGAIN_DB}dB,\
aresample=${OS_RATE}:resampler=soxr:precision=28,\
alimiter=limit=${LIMIT_MP3}:attack=2:release=80:level=disabled,\
aresample=${NATIVE_RATE}:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05_limited_mp3src.wav" 2>/dev/null

# --- DELIVERABLES ---
echo "[F] Deliverable 1: 32-bit float WAV 48k (archival)"
cp "$INT/05_limited.wav" "$OUT/${NAME}_MASTER_32f.wav"

echo "[F] Deliverable 2: 16-bit WAV 48k + TPDF dither (distribution)"
ffmpeg -hide_banner -nostats -y -i "$INT/05_limited.wav" \
    -af "aresample=osf=s16:dither_method=triangular_hp" \
    -c:a pcm_s16le "$OUT/${NAME}_MASTER_16.wav" 2>/dev/null

echo "[F] Deliverable 3: 320 kbps CBR MP3 (joint stereo, from true-peak-safe source)"
ffmpeg -hide_banner -nostats -y -i "$INT/05_limited_mp3src.wav" \
    -c:a libmp3lame -b:a 320k -compression_level 0 -joint_stereo 1 \
    "$OUT/${NAME}_MASTER.mp3" 2>/dev/null

echo ""
echo "============ FINAL LOUDNESS REPORT ============"
for f in "$OUT/${NAME}_MASTER_32f.wav" "$OUT/${NAME}_MASTER_16.wav" "$OUT/${NAME}_MASTER.mp3"; do
    echo ""
    echo "$(basename "$f")"
    ffmpeg -hide_banner -nostats -i "$f" \
        -af "ebur128=peak=true:framelog=quiet" -f null - 2>&1 | \
        tail -14 | grep -E "I:|LRA:|Peak:"
done

echo ""
echo "Done. Deliverables in: $OUT/"
