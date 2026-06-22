#!/bin/bash
# ============================================================
# master_pipeline_Sieh_zu.sh — Sieh zu (Ex-) Hardcore Pop x dr Khans
# Per-track invocation of the v3 orchestrator (master_pipeline_v3.sh)
# Target: -10.0 LUFS integrated, <= -1.0 dBTP (house default profile)
#
# TUNED FOR THIS SOURCE, as deliberate deltas from its nearest
# sibling (I_ccan_Tell_Hardcore_Pop_2 / "ICT2", 48 kHz family):
#   - source -14.9 LUFS — QUIETEST HP source measured yet (ICT2 -14.1)
#     -> large pre-gain, calibrated by sweep
#   - LRA 3.0 / crest 13.1 dB -> macro-COMPACT but micro-DYNAMIC:
#     low loudness range, high peak-to-loudness crest. Light glue only
#     (R 1.4 @ -16 dB), cohesion not density; protects the flagged PSR.
#   - FLAT DARK TOP: presence -31.9 / brilliance -31.7 / air -31.9, all
#     within 0.2 dB (even flatter than ICT2's 0.6 dB spread). BUT the top
#     sits only ~9.7 dB below bass here vs ICT2's ~14.8 dB -> top is LESS
#     buried -> GENTLER HF ladder than ICT2: air +1.3 (vs ICT2 +2.0),
#     presence/brilliance lifts moderated to match the shallower deficit.
#   - BASS-DOMINANT, clean low end (subbass -21.9 strongest, bass -22.1) ->
#     only -0.6 dB low-mid clarity insurance @ 230 Hz; NO bass boost under
#     ~+10 dB of make-up + 17.6 dB pre-gain.
#   - DC offset -0.000192 (small, NEGATIVE sign — opposite ICT2's positive
#     +0.000419) -> dcshift=+0.000192 (positive correction for a negative
#     source offset; stage re-enabled).
#   - premaster full-band min correlation -0.5396 (Gate 1 FAIL, marginal:
#     -0.54 vs -0.50 threshold) — among the LEAST-affected in the family;
#     per-register MEANS all positive (sub +0.78, lowmid +0.69, mid +0.57,
#     high +0.64), full-band mean +0.7271. This is the STANDING family mix
#     defect, escalated to the DAW, not re-patched per track. No stems to
#     return to -> PROCEED with defect logged, widening auto-SKIP, and
#     mono-safety PROVEN empirically on the master (qc_translation).
#   - PSR 9.7 (Gate 5 FLAG): micro-dynamics are a SOURCE property; glue
#     kept light to avoid eroding it further.
#
# CALIBRATION (empirical sweeps through the REAL E0->E1 module):
#   pre-gain: end-of-D = -21.6 LUFS; shortcut predicted +11.6.
#     Sweep @ ceiling -1.0 dBTP: +11.6=-15.6 (limiter idle), +14.5=-12.7,
#     +16.5=-10.8, +17.4=-10.1, +17.6=-10.0, +17.8=-9.8.
#     -> LOCKED +17.6 dB -> -10.0 LUFS / -1.4 dBTP / LRA 2.3.
#     FRAMEWORK NOTE: the shortcut UNDERSHOT by 6.0 dB despite a low LRA
#     (3.0). The undershoot tracks CREST FACTOR (peak-to-loudness, 13.1 dB
#     here), NOT loudness range. A macro-compact but micro-dynamic source
#     gives the limiter ~6 dB of transient headroom to convert into
#     integrated loudness once driven in. LRA alone does not predict the
#     shortcut; bracketing remains mandatory.
#   MP3 ceiling sweep @ +17.6: 0.86=-1.0 (no margin), 0.84=-1.0 (no
#     margin), 0.83=-1.2 (PASS, integrated -10.0), 0.82=-1.2 (integrated
#     -10.1), 0.80=-1.3. -> LOCKED 0.83 (highest ceiling holding a >=0.2 dB
#     true-peak margin while preserving -10.0 integrated).
#
# E0 CLIP-OF-RECORD SUBSTITUTION (this environment):
#   Airwindows ClipOnly2's LV2 build was unavailable (upstream host
#   unreachable). E0_CLIPPER=ffhard selects the deterministic pure-ffmpeg
#   4x-oversampled hard clip, role-faithful to ClipOnly2 ("shave the overs,
#   transparent below"). It avoids the LSP clipper's loudness-altering
#   lufs_on/boost defaults. The true-peak GUARANTEE is E1's job (alimiter
#   4x soxr scaffold, limiter of record) regardless of E0, so compliance is
#   unaffected. Both LV2 options remain preserved behind E0_CLIPPER.
#
# Usage: bash master_pipeline_Sieh_zu.sh [source.wav] [name] [project_dir]
# ============================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

SOURCE="${1:-source/Sieh_zu_Ex_Hardcore_Pop_x_dr_Khans.wav}"
NAME="${2:-Sieh_zu_Ex_Hardcore_Pop_x_dr_Khans}"
PROJECT_DIR="${3:-.}"

export LV2_PATH="${LV2_PATH:-/usr/lib/lv2:/usr/lib/x86_64-linux-gnu/lv2:/usr/local/lib/lv2:/usr/local/lib/x86_64-linux-gnu/lv2}"

PREGAIN_DB=17.6 \
DCSHIFT="0.000192" \
MP3_CEIL=0.83 \
E0_CLIPPER=ffhard \
EQ_CHAIN="equalizer=f=230:t=q:w=1.1:g=-0.6,equalizer=f=3000:t=q:w=1.2:g=0.8,equalizer=f=6500:t=q:w=1.0:g=1.0,equalizer=f=11000:t=q:w=0.7:g=1.3" \
COMP="acompressor=threshold=-16dB:ratio=1.4:attack=25:release=200:makeup=1.3:knee=5" \
bash "$HERE/master_pipeline_v3.sh" "$SOURCE" "$NAME" "$PROJECT_DIR"
