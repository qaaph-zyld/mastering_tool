#!/bin/bash
# ============================================================
# master_pipeline_ICT2.sh — I_ccan_Tell_Hardcore_Pop_2
# Per-track invocation of the v3 orchestrator (master_pipeline_v3.sh)
# Target: -10.0 LUFS integrated, <= -1.0 dBTP (house default profile)
#
# TUNED FOR THIS SOURCE, as deliberate deltas from its nearest
# siblings (the 48 kHz "Hardcore_Pop_2" family):
#   - source -14.1 LUFS — QUIETEST HP2 source yet (ATTSS2 -13.2) ->
#     large pre-gain, calibrated by sweep
#   - LRA 4.2 / crest 10.7 dB -> COMPACT source (vs ATTSS2's 7.6/14.4):
#     light glue only (R 1.5 @ -15 dB), cohesion not density
#   - FLAT DARK TOP: presence -33.7 / brilliance -34.3 / air -34.2
#     all within 0.6 dB (Overthinkk-type profile, NOT ATTSS2's
#     rolled-off-below-brilliance air) -> graduated HF ladder with a
#     MODERATED +2.0 air lift (Overthinkk precedent), not ATTSS2's +2.5
#   - BASS-DOMINANT, CLEAN low end (bass -19.2 strongest, lowmid -22.3
#     a clean 3.1 dB below) -> only -0.8 dB low-mid clarity insurance;
#     NO bass boost under ~+10 dB of make-up gain
#   - DC offset +0.000419 (above family ~0.0004 threshold, POSITIVE
#     sign — first in family) -> dcshift=-0.000419 (stage re-enabled)
#   - min phase correlation -0.822 — WORST MINIMUM MEASURED IN THE
#     FAMILY -> widening SKIP fired automatically by family_policy
#     (extrastereo held inert at m=1.00; stage retained)
#   - mean correlation +0.735 is healthy: mono fold-down excess
#     cancellation only 0.2 LU -> PASS mono-safe
#
# CALIBRATION (empirical sweeps through the REAL E0->E1 module):
#   pre-gain: end-of-D = -19.6 LUFS; shortcut predicted +9.6.
#     Sweep @ ceiling -1.0 dBTP: +9.6=-10.0, +10.0=-9.7, +10.4=-9.3.
#     -> LOCKED +9.6 dB -> -10.0 LUFS / -1.4 dBTP / LRA 3.8.
#     FRAMEWORK NOTE: the formula landed EXACTLY here — undershoot is
#     dynamics-dependent; this compact source (LRA 4.2) barely engages
#     the limiter. Bracketing remains mandatory: it is how we KNOW.
#   MP3 ceiling sweep @ +9.6: 0.85=-1.0 (no margin), 0.82=-1.3 (PASS),
#     0.80=-1.4. -> LOCKED 0.82 (gentle reconstructor, like ATTSS2).
#
# FRAMEWORK FIX THIS SESSION (stage_clip_limit.sh):
#   the module's output ffmpeg calls omitted -c:a pcm_f32le, so the
#   WAV default (pcm_s16le) silently truncated the limited master to
#   16-bit — making the "32f archival" a mislabeled 16-bit file and
#   feeding the TPDF dither stage already-quantized audio. Fixed by
#   forcing pcm_f32le on every module output (precision fix; no
#   feature change). Verified: deliverables now genuinely flt / s16
#   and differ byte-wise.
#
# Usage: bash master_pipeline_ICT2.sh [source.wav] [name] [project_dir]
# ============================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

SOURCE="${1:-source/I_ccan_Tell_Hardcore_Pop_2.wav}"
NAME="${2:-I_ccan_Tell_Hardcore_Pop_2}"
PROJECT_DIR="${3:-.}"

export LV2_PATH="${LV2_PATH:-/usr/lib/x86_64-linux-gnu/lv2:/usr/lib/lv2:/usr/local/lib/lv2:/usr/local/lib/x86_64-linux-gnu/lv2}"

PREGAIN_DB=9.6 \
DCSHIFT="-0.000419" \
MP3_CEIL=0.82 \
EQ_CHAIN="equalizer=f=220:t=q:w=1.1:g=-0.8,equalizer=f=3200:t=q:w=1.2:g=1.2,equalizer=f=6000:t=q:w=1.0:g=1.5,equalizer=f=11000:t=q:w=0.7:g=2.0" \
COMP="acompressor=threshold=-15dB:ratio=1.5:attack=20:release=180:makeup=1.5:knee=4" \
bash "$HERE/master_pipeline_v3.sh" "$SOURCE" "$NAME" "$PROJECT_DIR"
