#!/bin/bash
# ============================================================================
# mix_phase_gate.sh — Premaster Phase-Coherence Acceptance Gate
# ============================================================================
# Framework module (additive). Runs the v2 per-frame correlation diagnostic on
# a PREMASTER (full band + per register) and emits PASS / FLAG / FAIL against
# PREMASTER_ACCEPTANCE_SPEC.md. On FLAG/FAIL it names WHICH register is
# anti-phase, so the track routes back to the mix with an actionable target —
# not a downstream mastering band-aid.
#
# Rationale (this is the decisive commercial gap): a famous in-genre release
# (Cunami-Violet) measures full-band corr min -0.058 and <120 Hz mean +0.80.
# Our Hardcore-Pop family runs chronic -0.36..-0.90 minima. That delta lives
# in the MIX, not in mastering; bass-mono can attenuate but never resolve it.
# This gate makes the mix requirement enforceable BEFORE mastering starts.
#
# Usage:
#   bash mix_phase_gate.sh <premaster.wav>
# Exit codes: 0 PASS · 1 FLAG (proceed with remediation) · 2 FAIL (return to mix)
#
# Gates (from PREMASTER_ACCEPTANCE_SPEC.md, tunable at top):
#   full-band corr min   > FULL_MIN_FAIL  (FAIL) ; > FULL_MIN_FLAG (FLAG)
#   low-band <120 corr   >= LOW_MEAN_FAIL (FAIL) ; >= LOW_MEAN_FLAG (FLAG)
#   headroom (sample pk) <= -HEADROOM_DB           (FLAG if hotter)
#   sample peak          <  0 dBFS                 (FAIL if clipped on input)
#
# FRAMEWORK LESSON: correlation MUST come from per-frame
# lavfi.aphasemeter.phase metadata aggregated in awk. grep on stdout returns
# empty (the recurring v1 bug). Re-snapshot the project if this regresses.
# ============================================================================
set -u

# ---- tunable gates ---------------------------------------------------------
FULL_MIN_FAIL=-0.50    # below this anywhere full-band => return to mix
FULL_MIN_FLAG=-0.20    # below this => flag, remediate (bass-mono) but proceed
LOW_MEAN_FAIL=0.40     # <120 Hz mean below this => return to mix
LOW_MEAN_FLAG=0.70     # <120 Hz mean below this => flag (reference shows +0.80)
HEADROOM_DB=3.0        # want sample peak <= -3 dBFS on a premaster

SRC="${1:?Usage: mix_phase_gate.sh <premaster.wav>}"
NAME="$(basename "$SRC")"

corr_band() { # $1=filter-prefix (may be empty)  -> "mean min max"
  local pre="$1"; [ -n "$pre" ] && pre="${pre},"
  ffmpeg -hide_banner -nostats -i "$SRC" \
    -af "${pre}aphasemeter=video=0,ametadata=print:key=lavfi.aphasemeter.phase:file=-" \
    -f null - 2>/dev/null \
  | awk -F= '/lavfi.aphasemeter.phase/ {s+=$2;n++; if(mn==""||$2<mn)mn=$2; if(mx==""||$2>mx)mx=$2}
             END {if(n==0){print "0 0 0"} else printf "%.4f %.4f %.4f", s/n, mn, mx}'
}

read -r F_MEAN F_MIN F_MAX   <<< "$(corr_band "")"
read -r SUB_MEAN SUB_MIN _   <<< "$(corr_band "lowpass=f=120")"
read -r LM_MEAN  LM_MIN  _   <<< "$(corr_band "highpass=f=120,lowpass=f=500")"
read -r MD_MEAN  MD_MIN  _   <<< "$(corr_band "highpass=f=500,lowpass=f=4000")"
read -r HI_MEAN  HI_MIN  _   <<< "$(corr_band "highpass=f=4000")"

SPK=$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "astats=measure_overall=Peak_level:measure_perchannel=0" -f null - 2>&1 \
  | grep "Peak level dB" | head -1 | awk -F: '{printf "%.2f", $NF}')

# ---- verdict logic ---------------------------------------------------------
STATUS="PASS"; REASONS=""
add() { REASONS="${REASONS}  - $1
"; }
worse() { [ "$1" = "FAIL" ] && STATUS="FAIL"; [ "$1" = "FLAG" ] && [ "$STATUS" != "FAIL" ] && STATUS="FLAG"; }

awk "BEGIN{exit !($F_MIN < $FULL_MIN_FAIL)}" && { worse FAIL; add "full-band corr min ${F_MIN} < ${FULL_MIN_FAIL} (severe anti-phase)"; } || \
awk "BEGIN{exit !($F_MIN < $FULL_MIN_FLAG)}" && { worse FLAG; add "full-band corr min ${F_MIN} < ${FULL_MIN_FLAG} (anti-phase moments)"; }

awk "BEGIN{exit !($SUB_MEAN < $LOW_MEAN_FAIL)}" && { worse FAIL; add "<120 Hz corr mean ${SUB_MEAN} < ${LOW_MEAN_FAIL} (bass not mono-coherent)"; } || \
awk "BEGIN{exit !($SUB_MEAN < $LOW_MEAN_FLAG)}" && { worse FLAG; add "<120 Hz corr mean ${SUB_MEAN} < ${LOW_MEAN_FLAG} (bass coherence below reference +0.80)"; }

awk "BEGIN{exit !($SPK >= 0)}"            && { worse FAIL; add "sample peak ${SPK} dBFS >= 0 (premaster is clipped on input)"; }
awk "BEGIN{exit !($SPK > -$HEADROOM_DB)}" && { worse FLAG; add "sample peak ${SPK} dBFS hotter than -${HEADROOM_DB} (insufficient headroom)"; }

# worst offending register (only informative if not PASS)
WORST=$(printf "sub %s\nlow-mid %s\nmid %s\nhigh %s\n" "$SUB_MIN" "$LM_MIN" "$MD_MIN" "$HI_MIN" | sort -k2 -n | head -1)

# ---- report ----------------------------------------------------------------
echo "============================================================"
echo " MIX PHASE GATE — $NAME"
echo "============================================================"
printf "  full band   : mean %s  min %s  max %s\n" "$F_MEAN" "$F_MIN" "$F_MAX"
printf "  <120 Hz sub : mean %s  min %s\n" "$SUB_MEAN" "$SUB_MIN"
printf "  120-500 low : mean %s  min %s\n" "$LM_MEAN" "$LM_MIN"
printf "  500-4k mid  : mean %s  min %s\n" "$MD_MEAN" "$MD_MIN"
printf "  >4k high    : mean %s  min %s\n" "$HI_MEAN" "$HI_MIN"
printf "  sample peak : %s dBFS\n" "$SPK"
echo "------------------------------------------------------------"
echo " VERDICT: $STATUS"
[ -n "$REASONS" ] && { echo " Reasons:"; printf "%b" "$REASONS"; echo "  Worst register: $WORST"; }
[ "$STATUS" = "FAIL" ] && echo " ACTION: return to mix — fix the worst register above, re-bounce."
[ "$STATUS" = "FLAG" ] && echo " ACTION: proceed; mastering bass-mono remediation justified and must be logged."
[ "$STATUS" = "PASS" ] && echo " ACTION: clear to master."
echo "GATE_RESULT name=${NAME} status=${STATUS} full_min=${F_MIN} sub_mean=${SUB_MEAN} peak=${SPK}"
echo "============================================================"

case "$STATUS" in PASS) exit 0;; FLAG) exit 1;; FAIL) exit 2;; esac
