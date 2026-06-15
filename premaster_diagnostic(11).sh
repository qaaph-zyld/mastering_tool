#!/bin/bash
# ============================================================
# Pre-Master Diagnostic v2 — single-shot full measurement report
# Captures: EBU R128 loudness, astats (peak/crest/DC/RMS),
#           stereo phase correlation (FIXED), octave-band spectrum
#
# v2 FIX (vs broken v1 in project snapshot):
#   The v1 stereo-correlation block grepped aphasemeter's log lines and
#   reliably produced EMPTY output. v2 instead injects per-frame
#   `lavfi.aphasemeter.phase` metadata and aggregates it to mean/min/max
#   via ametadata=print -> awk. We ALSO derive mid/side RMS separately
#   (the most reliable mono-safety signal for this family).
#
# Usage: bash premaster_diagnostic.sh <source.wav> [report.txt]
# ============================================================
set -e

SOURCE="$1"
REPORT="${2:-/dev/stdout}"
if [ -z "$SOURCE" ]; then echo "Usage: $0 <source.wav> [report.txt]"; exit 1; fi

{
echo "============================================================"
echo " PRE-MASTER DIAGNOSTIC v2"
echo " Source: $SOURCE"
echo " Date:   $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================================"

# --- Container / format ---
echo ""
echo "=== FORMAT ==="
ffprobe -hide_banner -v error \
    -show_entries stream=codec_name,sample_rate,channels,sample_fmt,bits_per_sample \
    -show_entries format=duration \
    -of default=noprint_wrappers=1 "$SOURCE"

# --- EBU R128: integrated loudness, LRA, true peak ---
echo ""
echo "=== EBU R128 (loudness / LRA / true peak) ==="
ffmpeg -hide_banner -nostats -i "$SOURCE" \
    -af "ebur128=peak=true:framelog=quiet" -f null - 2>&1 | \
    tail -14 | grep -E "I:|LRA:|Threshold:|Peak:|range:|low:|high:"

# --- astats: sample peak, RMS, crest factor, DC offset ---
echo ""
echo "=== ASTATS (peak / RMS / crest / DC offset) ==="
ffmpeg -hide_banner -nostats -i "$SOURCE" \
    -af "astats=measure_perchannel=0:measure_overall=Peak_level+RMS_level+Crest_factor+DC_offset" \
    -f null - 2>&1 | grep -E "Peak level dB|RMS level dB|Crest factor|DC offset" | head -8

# --- Stereo phase correlation (mean / min / max)  [v2 FIX] ---
echo ""
echo "=== STEREO PHASE CORRELATION (v2: aphasemeter metadata -> awk) ==="
ffmpeg -hide_banner -nostats -i "$SOURCE" \
    -af "aphasemeter=video=0,ametadata=print:key=lavfi.aphasemeter.phase:file=-" \
    -f null - 2>/dev/null | \
    awk -F'=' '/lavfi.aphasemeter.phase/ {
        v=$2; n++; sum+=v;
        if (n==1){min=v; max=v}
        if (v<min) min=v;
        if (v>max) max=v;
    }
    END {
        if (n>0) printf "  frames=%d   mean=%.3f   min=%.3f   max=%.3f\n", n, sum/n, min, max;
        else print "  (no phase frames captured)";
    }'

# --- Mid / Side RMS (most reliable mono-safety signal for this family) ---
echo ""
echo "=== MID / SIDE RMS (mono-safety) ==="
MID=$(ffmpeg -hide_banner -nostats -i "$SOURCE" \
    -af "pan=mono|c0=0.5*c0+0.5*c1,astats=measure_overall=RMS_level:measure_perchannel=0" \
    -f null - 2>&1 | grep "RMS level dB" | head -1 | awk -F: '{print $NF}' | tr -d ' \r')
SIDE=$(ffmpeg -hide_banner -nostats -i "$SOURCE" \
    -af "pan=mono|c0=0.5*c0-0.5*c1,astats=measure_overall=RMS_level:measure_perchannel=0" \
    -f null - 2>&1 | grep "RMS level dB" | head -1 | awk -F: '{print $NF}' | tr -d ' \r')
printf "  MID RMS  : %10s dB\n" "$MID"
printf "  SIDE RMS : %10s dB\n" "$SIDE"

# --- Octave-band spectral energy (RMS per band) ---
echo ""
echo "=== OCTAVE-BAND SPECTRAL ENERGY (RMS dB) ==="
labels=(
  "20-60Hz subbass" "60-120Hz bass" "120-250Hz lowmid" "250-500Hz mid"
  "500-1k mid" "1k-2k upmid" "2k-4k presence" "4k-8k brilliance"
  "8k-16k air" "16k+ ultra"
)
filters=(
  "highpass=f=20,lowpass=f=60" "highpass=f=60,lowpass=f=120"
  "highpass=f=120,lowpass=f=250" "highpass=f=250,lowpass=f=500"
  "highpass=f=500,lowpass=f=1000" "highpass=f=1000,lowpass=f=2000"
  "highpass=f=2000,lowpass=f=4000" "highpass=f=4000,lowpass=f=8000"
  "highpass=f=8000,lowpass=f=16000" "highpass=f=16000"
)
for i in "${!labels[@]}"; do
    rms=$(ffmpeg -hide_banner -nostats -i "$SOURCE" \
        -af "${filters[$i]},astats=measure_overall=RMS_level:measure_perchannel=0" \
        -f null - 2>&1 | grep "RMS level dB" | head -1 | awk -F: '{print $NF}' | tr -d ' \r')
    printf "  %-20s : %10s dB\n" "${labels[$i]}" "$rms"
done

echo ""
echo "============================================================"
echo " END DIAGNOSTIC"
echo "============================================================"
} | tee "$REPORT"
