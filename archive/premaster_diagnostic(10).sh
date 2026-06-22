#!/bin/bash
# ============================================================
# Pre-master diagnostic — runs every measurement the mastering
# pipeline needs to make tuning decisions. Single command, single
# report. Drop-in for the project framework.
# ============================================================
SOURCE="$1"
if [ -z "$SOURCE" ]; then echo "Usage: $0 <source.wav> [report.txt]"; exit 1; fi
REPORT="${2:-/dev/stdout}"

{
echo "============================================================"
echo " PRE-MASTER DIAGNOSTIC"
echo " Source: $SOURCE"
echo " Date  : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================================"
echo ""
echo "--- Container / stream ---"
ffprobe -hide_banner -i "$SOURCE" 2>&1 | grep -E "Duration|Stream"
echo ""

echo "--- EBU R128 (integrated loudness / LRA / true peak) ---"
ffmpeg -hide_banner -nostats -i "$SOURCE" \
  -af "ebur128=peak=true:framelog=quiet" -f null - 2>&1 | \
  awk '/Integrated loudness|Loudness range|True peak|^[[:space:]]+I:|LRA:|Threshold:|LRA low|LRA high|Peak:/{print}'
echo ""

echo "--- astats (DC offset, sample peak, RMS, crest factor) ---"
ffmpeg -hide_banner -nostats -i "$SOURCE" -af "astats" -f null - 2>&1 | \
  grep -E "Channel:|DC offset|Peak level|RMS level dB|Crest factor|^\[Parsed.*Overall"
echo ""

echo "--- Stereo phase correlation (aphasemeter) ---"
ffmpeg -hide_banner -nostats -i "$SOURCE" \
  -af "aphasemeter=video=0,ametadata=mode=print:key=lavfi.aphasemeter.phase:file=- " \
  -f null - 2>/dev/null | \
  awk -F= '/phase/{n++; v=$2+0; s+=v; if(n==1||v<mn)mn=v; if(n==1||v>mx)mx=v}
           END{printf "phase samples=%d  mean=%.3f  min=%.3f  max=%.3f\n", n, s/n, mn, mx}'
echo ""

echo "--- Octave-band RMS spectrum ---"
labels=("20-60Hz subbass" "60-120Hz bass" "120-250Hz lowmid" "250-500Hz mid" "500-1k mid" \
        "1k-2k upmid" "2k-4k presence" "4k-8k brilliance" "8k-16k air" "16k+ ultra")
filters=("highpass=f=20,lowpass=f=60" "highpass=f=60,lowpass=f=120" \
         "highpass=f=120,lowpass=f=250" "highpass=f=250,lowpass=f=500" \
         "highpass=f=500,lowpass=f=1000" "highpass=f=1000,lowpass=f=2000" \
         "highpass=f=2000,lowpass=f=4000" "highpass=f=4000,lowpass=f=8000" \
         "highpass=f=8000,lowpass=f=16000" "highpass=f=16000")
for i in "${!labels[@]}"; do
    rms=$(ffmpeg -hide_banner -nostats -i "$SOURCE" \
        -af "${filters[$i]},astats=measure_overall=RMS_level:measure_perchannel=0" \
        -f null - 2>&1 | grep "RMS level dB" | head -1 | awk -F: '{print $NF}' | tr -d ' \r')
    printf "  %-22s : %10s dB\n" "${labels[$i]}" "$rms"
done
echo ""
echo "============================================================"
echo " Use these numbers to tune the chain in master_pipeline.sh:"
echo "  - Integrated loudness  → pre-limit gain target (Stage E)"
echo "  - True peak            → headroom strategy (Stage A)"
echo "  - LRA                  → compression intensity (Stage C)"
echo "  - Stereo phase min     → widening safety (Stage D)"
echo "  - Spectral slope       → EQ moves (Stage B)"
echo "============================================================"
} > "$REPORT"

[ "$REPORT" != "/dev/stdout" ] && echo "Diagnostic written to: $REPORT"
