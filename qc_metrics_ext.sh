#!/bin/bash
# ============================================================================
# qc_metrics_ext.sh — Additive QC Metrics for MASTERING_REPORT.md
# ============================================================================
# Framework module (additive — extends qc_verify.sh; changes no master).
# Emits the four metric blocks the Violet gap analysis identified as missing,
# for any finished master WAV, in markdown-ready form plus a machine footer.
#
#   1. Short-term density: p50/p90/p99 + spread (p99-p50). Reference 1.1 LU.
#   2. Clipping census: per-channel full-scale peak count + flat factor
#      (detects unintended flat-topping in OUR masters).
#   3. Mono fold-down loss, R128 baseline-corrected (-3.01 LU). Reference 0.3 LU.
#   4. Low-band (<120 Hz) correlation mean/min. Reference mean +0.80.
#
# Usage: bash qc_metrics_ext.sh <master.wav>
#
# Determinism: offline analysis only; identical output across runs.
# LESSON: mono fold raw loss must be reduced by 3.01 LU (the R128 stereo-sum
# baseline) before it reflects true phase loss.
# ============================================================================
set -u
SRC="${1:?Usage: qc_metrics_ext.sh <master.wav>}"
NAME="$(basename "$SRC")"

I=$(ffmpeg -hide_banner -nostats -i "$SRC" -af "ebur128=peak=true" -f null - 2>&1 \
    | grep -A2 "Integrated loudness" | grep "I:" | awk '{print $2}')
TP=$(ffmpeg -hide_banner -nostats -i "$SRC" -af "ebur128=peak=true" -f null - 2>&1 \
    | grep -A2 "True peak" | grep "Peak:" | awk '{print $2}')

read -r P50 P90 P99 SMAX <<< "$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "ebur128=metadata=1,ametadata=print:key=lavfi.r128.S:file=-" -f null - 2>/dev/null \
  | awk -F= '/lavfi.r128.S/ && $2 > -70 {print $2}' | sort -n \
  | awk '{a[NR]=$1} END {printf "%.1f %.1f %.1f %.1f", a[int(NR*0.5)], a[int(NR*0.9)], a[int(NR*0.99)], a[NR]}')"
SPREAD=$(awk -v a="$P99" -v b="$P50" 'BEGIN{printf "%.1f", a-b}')
PSR=$(awk -v t="$TP" -v s="$SMAX" 'BEGIN{printf "%.1f", t-s}')

AST=$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "astats=measure_perchannel=Peak_count+Flat_factor:measure_overall=none" -f null - 2>&1)
PC_L=$(echo "$AST" | grep -A4 "Channel: 1" | grep "Peak count" | awk -F: '{print $NF}' | tr -d ' ')
PC_R=$(echo "$AST" | grep -A4 "Channel: 2" | grep "Peak count" | awk -F: '{print $NF}' | tr -d ' ')
FLAT=$(echo "$AST" | grep -A4 "Channel: 1" | grep "Flat factor" | head -1 | awk -F: '{printf "%.1f", $NF}')

MONO_I=$(ffmpeg -hide_banner -nostats -i "$SRC" -af "pan=mono|c0=0.5*c0+0.5*c1,ebur128" -f null - 2>&1 \
  | grep -A2 "Integrated loudness" | grep "I:" | awk '{print $2}')
MONO_LOSS=$(awk -v s="$I" -v m="$MONO_I" 'BEGIN{printf "%.1f", (s-m)-3.01}')

read -r LB_MEAN LB_MIN <<< "$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "lowpass=f=120,aphasemeter=video=0,ametadata=print:key=lavfi.aphasemeter.phase:file=-" -f null - 2>/dev/null \
  | awk -F= '/lavfi.aphasemeter.phase/ {s+=$2;n++; if(mn==""||$2<mn)mn=$2} END {printf "%.4f %.4f", s/n, mn}')"

# flags vs reference-derived expectations
flag() { awk "BEGIN{exit !($1)}" && echo "$2" || echo "OK"; }
F_PSR=$(flag "$PSR < 7.5" "FLAG <7.5")
F_SPREAD=$(flag "$SPREAD > 3.0" "FLAG >3.0 (loose density)")
F_FLAT=$(flag "$FLAT > 10" "FLAG: heavy flat-topping")
F_MONO=$(flag "$MONO_LOSS > 1.0" "FLAG >1.0 LU phase loss")
F_LB=$(flag "$LB_MEAN < 0.4" "FLAG: bass not coherent")

cat <<MD

### QC metrics (extended) — $NAME

| Metric | Value | Ref (Violet) | Flag |
|---|---|---|---|
| Integrated | ${I} LUFS | −8.0 | — |
| True peak | ${TP} dBTP | +1.1 | — |
| Max short-term | ${SMAX} LUFS | −6.8 | — |
| PSR (TP − max ST) | ${PSR} dB | 7.9 | ${F_PSR} |
| ST p50 / p90 / p99 | ${P50} / ${P90} / ${P99} | −7.9/−7.1/−6.9 | — |
| ST spread (p99−p50) | ${SPREAD} LU | 1.1 | ${F_SPREAD} |
| Clipping count L/R | ${PC_L} / ${PC_R} | 19227/18049 | — |
| Flat factor | ${FLAT} | 14.4 | ${F_FLAT} |
| Mono fold loss (corr.) | ${MONO_LOSS} LU | 0.3 | ${F_MONO} |
| <120 Hz corr mean/min | ${LB_MEAN} / ${LB_MIN} | +0.80/−0.06 | ${F_LB} |

QC_EXT name=${NAME} psr=${PSR} st_spread=${SPREAD} flat=${FLAT} mono_loss=${MONO_LOSS} lowband_mean=${LB_MEAN}
MD
