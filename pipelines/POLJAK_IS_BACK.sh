#!/bin/bash
# ============================================================
# FFmpeg Mastering Pipeline — POLJAK_IS_BACK_TRACK_BB2026
# Target: -10 LUFS integrated, <= -1.0 dBTP true peak
# Source: 320 kbps MP3 (LOSSY), 44.1 kHz, stereo, 3:18.87
#         -> decoded once to 32-bit float WAV; pipeline runs on that
# Chain: prep(+DC) -> EQ -> comp -> (no widen) -> 4x oversampled limit
#
# *** FIRST LOSSY SOURCE IN THE PROJECT ***  and a profile that is the
# INVERSE of the recent quiet Hardcore Pop / trap run — it maps onto the
# ORIGINAL zeldi_bumbap reference (loud + clipping), but even more dynamic:
#   - ALREADY LOUD: -10.2 LUFS (already at target; do NOT add loudness)
#   - CLIPPING: sample peak +2.44 dBFS (inter-sample clipping baked into
#     the lossy master) -> THE headline fix is the oversampled limiter
#   - MOST DYNAMIC track to date: LRA 10.2, crest 14.7 dB -> PRESERVE the
#     dynamics; only gentle-moderate glue, no squashing
#   - bass-led, strong + clean low end (no mud) -> no low EQ
#   - moderately dark top (sub->air 11.9 dB) -> modest air lift
#   - LARGEST DC offset in project (-0.0015) -> DC correction APPLIED
#     (prior tracks skipped it at <0.0005)
#   - phase UNSAFE for widening: min -0.542, 10.9% of frames <0, 2.0%
#     <-0.2 (vs rodjen's safe 2.3%/0.4%) -> widening SKIPPED
#   - NATIVE 44.1 kHz -> oversample target 176.4 kHz (4x), NOT 192 kHz
#     (the recent 48 kHz tracks used 192; this reverts to the zeldi value)
#
# LOSSY-SOURCE CAVEAT: the source is 320 kbps MP3, so the "32f archival"
# deliverable is NOT a true lossless archival master — it is the best
# possible render FROM a lossy source. The MP3 deliverable is therefore a
# SECOND lossy generation (transcode of a transcode); the 16-bit WAV is the
# recommended canonical distribution master. See MASTERING_REPORT.md.
# Because of that second-gen MP3, the limiter ceiling was lowered to 0.82
# (-1.72 dBFS) so the MP3's codec overshoot still lands <= -1.0 dBTP.
# ============================================================
set -e

# Working source = the decoded 32-bit float WAV (decode the MP3 once, upstream).
SOURCE="${1:-source/POLJAK_IS_BACK_decoded_32f.wav}"
NAME="${2:-POLJAK_IS_BACK}"
PROJECT_DIR="${3:-.}"

INT="${PROJECT_DIR}/intermediate"
OUT="${PROJECT_DIR}/master"
mkdir -p "$INT" "$OUT"

echo ">>> Source: $SOURCE"

# --- STAGE A: Headroom + DC correction + subsonic HPF ---
# volume=-6dB    -> pulls the clipping +2.44 dBFS peak down to ~-2.8 dBFS
# dcshift=0.001498 -> recenters the -0.0015 DC offset (largest in project)
# highpass 25Hz  -> 12 dB/oct subsonic filter
echo "[A] Headroom (-6dB, clipping source), DC correction (+0.001498), HPF 25Hz/12dB"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
    -af "volume=-6dB,dcshift=0.001498,highpass=f=25:poles=2" \
    -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: Parametric EQ (light, top-focused; no low EQ) ---
# +0.5dB @ 3.5k Q1.2 -> gentle presence
# +0.5dB @ 7k   Q1.0 -> brilliance bridge (sparkle)
# +1.2dB @ 12k  Q0.7 -> modest air lift (top ~12 dB dark; moderate, not big)
# (no low-end EQ: bass-led, strong + clean, no mud build-up -> preserve it)
echo "[B] Parametric EQ (presence + brilliance + modest air; no low EQ)"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" \
    -af "equalizer=f=3500:t=q:w=1.2:g=0.5,\
equalizer=f=7000:t=q:w=1.0:g=0.5,\
equalizer=f=12000:t=q:w=0.7:g=1.2" \
    -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: Bus compression (gentle-moderate glue, dynamics-preserving) ---
# th -16dB, ratio 1.7, attack 20ms, release 180ms, knee 4, makeup 1.2
# Firmer than the recent gentle tier (R 1.4-1.5) because LRA 10.2 gives
# plenty of macro-dynamic room; but deliberately restrained (vs zeldi's 1.8)
# to PRESERVE the unusually high crest (14.7 dB) / wide LRA. Goal is cohesion,
# NOT loudness (the source is already at -10.2 LUFS). 20 ms attack keeps the
# transient life; 180 ms release musical pumping; makeup 1.2 modest so the
# limiter is not slammed (protects the dynamics).
echo "[C] Bus compression (gentle-moderate glue)"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" \
    -af "acompressor=threshold=-16dB:ratio=1.7:attack=20:release=180:makeup=1.2:knee=4" \
    -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null

# --- STAGE D: Headroom prep (NO widening) ---
# extrastereo SKIPPED: min phase correlation -0.542 and 10.9% of frames < 0
# (2.0% < -0.2) -> widening would break mono fold-down. (Contrast rodjen,
# where 2.3%/0.4% made gentle widening safe.) This source is already wide.
echo "[D] Headroom prep (-3dB)  [stereo widening skipped for mono safety]"
ffmpeg -hide_banner -nostats -y -i "$INT/03_comp.wav" \
    -af "volume=-3dB" \
    -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null

# --- STAGE E: 4x oversampled true-peak limiting (THE headline fix) ---
# +10.1dB pre-gain -> upsample 4x (44.1->176.4kHz) soxr -> alimiter @0.82
# (-1.72dBFS) -> downsample back to 44.1kHz. The oversampling catches the
# inter-sample reconstruction overshoot that produced the +2.44 dBFS clip.
#
# LIMITER CEILING LOWERED to 0.82 (-1.72 dBFS) — vs 0.85 (-1.41 dBFS) on the
# WAV-sourced tracks — specifically because the MP3 deliverable here is a
# SECOND lossy generation: at ceiling 0.85 the WAV landed -1.3 dBTP and the
# MP3 re-encode overshot to -0.9 dBTP, breaching the -1.0 ceiling. At 0.82
# the WAV lands -1.6 dBTP, giving the second-gen MP3 codec overshoot room to
# stay <= -1.0 dBTP. Verified in the verification/ report.
#
# Pre-gain locked empirically: stage D measured -19.1 LUFS; +10.1 dB lands
# -10.1 LUFS while holding LRA at 7.0 (dynamics preserved). Pushing further
# (+10.3) did not raise integrated loudness, only eroded LRA -> +10.1 chosen.
echo "[E] 4x oversampled true-peak limiting (+10.1dB / 176.4kHz / ceiling 0.82)"
ffmpeg -hide_banner -nostats -y -i "$INT/04_stereo.wav" \
    -af "volume=+10.1dB,\
aresample=176400:resampler=soxr:precision=28,\
alimiter=limit=0.82:attack=2:release=80:level=disabled,\
aresample=44100:resampler=soxr:precision=28" \
    -c:a pcm_f32le "$INT/05_limited.wav" 2>/dev/null

# --- DELIVERABLES ---
echo "[F] Deliverable 1: 32-bit float WAV (best render from lossy source; see caveat)"
cp "$INT/05_limited.wav" "$OUT/${NAME}_MASTER_32f.wav"

echo "[F] Deliverable 2: 16-bit WAV with TPDF dither (CD/distribution; canonical)"
ffmpeg -hide_banner -nostats -y -i "$INT/05_limited.wav" \
    -af "aresample=osf=s16:dither_method=triangular_hp" \
    -c:a pcm_s16le "$OUT/${NAME}_MASTER_16.wav" 2>/dev/null

echo "[F] Deliverable 3: 320 kbps CBR MP3 (joint stereo; SECOND lossy generation)"
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
