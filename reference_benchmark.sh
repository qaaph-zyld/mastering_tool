#!/bin/bash
# ============================================================================
# reference_benchmark.sh — Commercial Reference Benchmark Scanner
# ============================================================================
# Framework module (additive — removes nothing, default pipeline untouched).
# Measures a commercial reference master with the SAME methodology as
# premaster_diagnostic.sh v2 + qc_verify.sh, and appends one machine-readable
# row to the standing REFERENCE_LIBRARY.csv.
#
# Usage:
#   bash reference_benchmark.sh <reference.wav> <library_dir>
#
# Outputs (in <library_dir>):
#   REFERENCE_LIBRARY.csv            — one row per scanned reference (append-only)
#   <name>_diagnostic.txt            — human-readable full metric dump
#   <name>_spectrogram.png           — log spectrogram (showspectrumpic)
#
# Metrics per reference:
#   format (sr/bits/duration), integrated LUFS, LRA, true peak dBTP,
#   sample peak dBFS, crest, PLR, PSR proxy (TP − max short-term),
#   max momentary, short-term percentiles p50/p90/p99 (density consistency),
#   full-band corr mean/min/max (v2 per-frame metadata aggregation),
#   low-band (<120 Hz) corr mean/min (bass-mono coherence),
#   mono fold-down loss (R128 −3.01 dB baseline-corrected),
#   clipping census (per-channel peak count + flat factor),
#   10-band octave RMS (identical bands to spectral_analysis.sh),
#   HF probes 14–16/16–18/18–20/20–22 kHz (cliff detection), DC offset.
#
# Determinism: all measurements are offline FFmpeg analysis passes —
# repeated runs on the same file produce identical numbers.
#
# FRAMEWORK LESSONS ENCODED:
# - Phase correlation MUST use per-frame lavfi.aphasemeter.phase metadata
#   aggregated in awk (grep on stdout returns empty — v1 bug).
# - Mono fold-down via pan=mono|c0=0.5*c0+0.5*c1 measures ~3.01 LU below the
#   stereo R128 sum even for perfectly correlated material; report the
#   baseline-corrected value (raw_loss − 3.01) as the true phase loss.
# - Commercial masters routinely violate −1.0 dBTP (e.g. Cunami–Violet:
#   sample peak 0.0 dBFS, true peak +1.1 dBTP, ~19k flat-topped samples per
#   channel). Library rows record this honestly; it is NOT a target to copy —
#   our codec round-trip QC gate is stricter than commercial practice.
# ============================================================================
set -u

SRC="${1:?Usage: reference_benchmark.sh <reference.wav> <library_dir>}"
LIB="${2:?Usage: reference_benchmark.sh <reference.wav> <library_dir>}"
mkdir -p "$LIB"

NAME="$(basename "$SRC" | sed 's/\.[^.]*$//' | tr ' ' '_')"
TXT="$LIB/${NAME}_diagnostic.txt"
CSV="$LIB/REFERENCE_LIBRARY.csv"
PNG="$LIB/${NAME}_spectrogram.png"

# ---------------------------------------------------------------- format ---
read -r SR CH BITS DUR <<EOF
$(ffprobe -v error -select_streams a:0 \
  -show_entries stream=sample_rate,channels,bits_per_sample \
  -show_entries format=duration -of csv=p=0 "$SRC" | tr ',\n' '  ')
EOF

# ------------------------------------------------------------- loudness ----
EBUR=$(ffmpeg -hide_banner -nostats -i "$SRC" -af "ebur128=peak=true" -f null - 2>&1)
I=$(echo "$EBUR"   | grep -A2 "Integrated loudness" | grep "I:" | awk '{print $2}')
LRA=$(echo "$EBUR" | grep -A2 "Loudness range"      | grep "LRA:" | awk '{print $2}')
TP=$(echo "$EBUR"  | grep -A2 "True peak"           | grep "Peak:" | awk '{print $2}')

ASTATS=$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "astats=measure_perchannel=Peak_level+Peak_count+Flat_factor:measure_overall=Peak_level+RMS_level+DC_offset" \
  -f null - 2>&1)
SPK=$(echo "$ASTATS"  | grep -A6 "Overall" | grep "Peak level dB" | awk -F: '{print $NF}' | tr -d ' ')
RMS=$(echo "$ASTATS"  | grep -A6 "Overall" | grep "RMS level dB"  | awk -F: '{print $NF}' | tr -d ' ')
DC=$(echo "$ASTATS"   | grep -A6 "Overall" | grep "DC offset"     | awk -F: '{print $NF}' | tr -d ' ')
PKCNT_L=$(echo "$ASTATS" | grep -A4 "Channel: 1" | grep "Peak count" | awk -F: '{print $NF}' | tr -d ' ')
PKCNT_R=$(echo "$ASTATS" | grep -A4 "Channel: 2" | grep "Peak count" | awk -F: '{print $NF}' | tr -d ' ')
FLAT=$(echo "$ASTATS"    | grep -A4 "Channel: 1" | grep "Flat factor" | awk -F: '{print $NF}' | tr -d ' ')

# --------------------------------------------- short-term / momentary ------
ST_STATS=$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "ebur128=metadata=1,ametadata=print:key=lavfi.r128.S:file=-" -f null - 2>/dev/null \
  | awk -F= '/lavfi.r128.S/ && $2 > -70 {print $2}' | sort -n \
  | awk '{a[NR]=$1} END {printf "%.2f %.2f %.2f %.2f", a[int(NR*0.5)], a[int(NR*0.9)], a[int(NR*0.99)], a[NR]}')
read -r ST_P50 ST_P90 ST_P99 ST_MAX <<EOF
$ST_STATS
EOF
M_MAX=$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "ebur128=metadata=1,ametadata=print:key=lavfi.r128.M:file=-" -f null - 2>/dev/null \
  | awk -F= '/lavfi.r128.M/ && $2 > -70 {if(m==""||$2>m)m=$2} END {printf "%.2f", m}')

PLR=$(awk -v tp="$TP" -v i="$I" 'BEGIN{printf "%.1f", tp - i}')
PSR=$(awk -v tp="$TP" -v st="$ST_MAX" 'BEGIN{printf "%.1f", tp - st}')
CREST=$(awk -v p="$SPK" -v r="$RMS" 'BEGIN{printf "%.1f", p - r}')
ST_SPREAD=$(awk -v a="$ST_P99" -v b="$ST_P50" 'BEGIN{printf "%.1f", a - b}')

# ---------------------------------------- phase correlation (v2 method) ----
CORR=$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "aphasemeter=video=0,ametadata=print:key=lavfi.aphasemeter.phase:file=-" -f null - 2>/dev/null \
  | awk -F= '/lavfi.aphasemeter.phase/ {s+=$2;n++; if(mn==""||$2<mn)mn=$2; if(mx==""||$2>mx)mx=$2}
             END {printf "%.4f %.4f %.4f", s/n, mn, mx}')
read -r CORR_MEAN CORR_MIN CORR_MAX <<EOF
$CORR
EOF
LB=$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "lowpass=f=120,aphasemeter=video=0,ametadata=print:key=lavfi.aphasemeter.phase:file=-" -f null - 2>/dev/null \
  | awk -F= '/lavfi.aphasemeter.phase/ {s+=$2;n++; if(mn==""||$2<mn)mn=$2}
             END {printf "%.4f %.4f", s/n, mn}')
read -r LB_MEAN LB_MIN <<EOF
$LB
EOF

# ----------------------------------------------------- mono fold-down ------
MONO_I=$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "pan=mono|c0=0.5*c0+0.5*c1,ebur128" -f null - 2>&1 \
  | grep -A2 "Integrated loudness" | grep "I:" | awk '{print $2}')
MONO_LOSS=$(awk -v s="$I" -v m="$MONO_I" 'BEGIN{printf "%.1f", (s - m) - 3.01}')

# ------------------------------------------------- octave-band spectral ----
declare -a BLAB=("20-60" "60-120" "120-250" "250-500" "500-1k" "1k-2k" "2k-4k" "4k-8k" "8k-16k" "16k+")
declare -a BFLT=("highpass=f=20,lowpass=f=60" "highpass=f=60,lowpass=f=120" \
  "highpass=f=120,lowpass=f=250" "highpass=f=250,lowpass=f=500" \
  "highpass=f=500,lowpass=f=1000" "highpass=f=1000,lowpass=f=2000" \
  "highpass=f=2000,lowpass=f=4000" "highpass=f=4000,lowpass=f=8000" \
  "highpass=f=8000,lowpass=f=16000" "highpass=f=16000")
BANDS_CSV=""; BANDS_TXT=""
for idx in "${!BLAB[@]}"; do
  v=$(ffmpeg -hide_banner -nostats -i "$SRC" \
      -af "${BFLT[$idx]},astats=measure_overall=RMS_level:measure_perchannel=0" \
      -f null - 2>&1 | grep "RMS level dB" | head -1 | awk -F: '{printf "%.1f", $NF}')
  BANDS_CSV="${BANDS_CSV},${v}"
  BANDS_TXT="${BANDS_TXT}$(printf '  %-10s : %7s dB (rel RMS %+.1f)\n' "${BLAB[$idx]}" "$v" "$(awk -v b="$v" -v r="$RMS" 'BEGIN{printf "%.1f", b-r}')")
"
done

# --------------------------------------------------------- HF probes -------
HF_CSV=""; HF_TXT=""
for f in "14000 16000" "16000 18000" "18000 20000" "20000 22000"; do
  set -- $f
  v=$(ffmpeg -hide_banner -nostats -i "$SRC" \
      -af "highpass=f=$1,lowpass=f=$2,astats=measure_overall=RMS_level:measure_perchannel=0" \
      -f null - 2>&1 | grep "RMS level dB" | head -1 | awk -F: '{printf "%.1f", $NF}')
  HF_CSV="${HF_CSV},${v}"
  HF_TXT="${HF_TXT}$(printf '  %5s-%-5s : %7s dB\n' "$1" "$2" "$v")
"
done

# -------------------------------------------------------- spectrogram ------
ffmpeg -hide_banner -y -i "$SRC" \
  -lavfi "showspectrumpic=s=1920x1080:legend=1:scale=log" "$PNG" 2>/dev/null

# ---------------------------------------------------------- text report ----
{
echo "============================================================"
echo " REFERENCE BENCHMARK — $NAME"
echo "============================================================"
echo "Format         : ${SR} Hz / ${BITS}-bit / ${CH}ch / ${DUR}s"
echo ""
echo "Integrated     : ${I} LUFS"
echo "LRA            : ${LRA} LU"
echo "True peak      : ${TP} dBTP"
echo "Sample peak    : ${SPK} dBFS"
echo "Overall RMS    : ${RMS} dB   Crest: ${CREST} dB"
echo "PLR            : ${PLR} dB   PSR proxy: ${PSR} dB"
echo "Max momentary  : ${M_MAX} LUFS   Max short-term: ${ST_MAX} LUFS"
echo "ST percentiles : p50=${ST_P50}  p90=${ST_P90}  p99=${ST_P99}  spread(p99-p50)=${ST_SPREAD} LU"
echo "DC offset      : ${DC}"
echo ""
echo "CORR_STATS mean=${CORR_MEAN} min=${CORR_MIN} max=${CORR_MAX}"
echo "LOWBAND(<120Hz) mean=${LB_MEAN} min=${LB_MIN}"
echo "Mono fold loss : ${MONO_LOSS} LU (R128 baseline-corrected)"
echo "Clipping census: peak_count L=${PKCNT_L} R=${PKCNT_R}  flat_factor=${FLAT}"
echo ""
echo "OCTAVE-BAND RMS:"
printf "%b" "$BANDS_TXT"
echo ""
echo "HF CLIFF PROBES:"
printf "%b" "$HF_TXT"
echo "============================================================"
} | tee "$TXT"

# ----------------------------------------------------------------- CSV -----
HDR="name,sr,bits,duration_s,integrated_lufs,lra_lu,true_peak_dbtp,sample_peak_dbfs,rms_db,crest_db,plr_db,psr_db,max_momentary,max_short_term,st_p50,st_p90,st_p99,st_spread,corr_mean,corr_min,corr_max,lowband_corr_mean,lowband_corr_min,mono_loss_lu,peak_count_l,peak_count_r,flat_factor,dc_offset,b20_60,b60_120,b120_250,b250_500,b500_1k,b1k_2k,b2k_4k,b4k_8k,b8k_16k,b16k_up,hf14_16,hf16_18,hf18_20,hf20_22"
[ -f "$CSV" ] || echo "$HDR" > "$CSV"
echo "${NAME},${SR},${BITS},${DUR},${I},${LRA},${TP},${SPK},${RMS},${CREST},${PLR},${PSR},${M_MAX},${ST_MAX},${ST_P50},${ST_P90},${ST_P99},${ST_SPREAD},${CORR_MEAN},${CORR_MIN},${CORR_MAX},${LB_MEAN},${LB_MIN},${MONO_LOSS},${PKCNT_L},${PKCNT_R},${FLAT},${DC}${BANDS_CSV}${HF_CSV}" >> "$CSV"
echo ""
echo "Row appended to $CSV"
