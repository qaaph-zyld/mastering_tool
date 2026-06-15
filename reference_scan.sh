#!/bin/bash
# ============================================================
# reference_scan.sh  —  measured reference-library scanner
# ------------------------------------------------------------
# Scans a folder of world-class genre references and logs one CSV
# row per track: integrated LUFS, max short-term, LRA, true peak,
# PLR, PSR estimate, spectral tilt (low/mid/high octave RMS), and
# low-band phase correlation. Build this over 10-20 references to
# derive the family's numeric tonal-balance + dynamics north star.
#
# Usage: bash reference_scan.sh <refs_dir> [out.csv]
# ============================================================
set -e
DIR="$1"; CSV="${2:-reference_library.csv}"
[ -z "$DIR" ] && { echo "Usage: $0 <refs_dir> [out.csv]"; exit 1; }

bandrms () { ffmpeg -hide_banner -nostats -i "$1" -af \
  "$2,astats=measure_overall=RMS_level:measure_perchannel=0" -f null - 2>&1 \
  | grep "RMS level" | head -1 | awk '{print $NF}'; }

echo "file,I_LUFS,Smax_LUFS,LRA,TP_dBFS,PLR,PSR,low_dB,mid_dB,high_dB,lowband_corr" > "$CSV"

shopt -s nullglob
for f in "$DIR"/*.wav "$DIR"/*.flac "$DIR"/*.mp3; do
  [ -e "$f" ] || continue
  EBU=$(ffmpeg -hide_banner -nostats -i "$f" -af "ebur128=peak=true:framelog=quiet" -f null - 2>&1)
  I=$(echo "$EBU"   | grep -E "^\s*I:"   | tail -1 | awk '{print $2}')
  LRA=$(echo "$EBU" | grep -E "^\s*LRA:" | head -1 | awk '{print $2}')
  TP=$(echo "$EBU"  | grep "Peak:"       | tail -1 | awk '{print $2}')
  SMAX=$(ffmpeg -hide_banner -nostats -i "$f" \
     -af "ebur128=peak=true:metadata=1,ametadata=mode=print:key=lavfi.r128.S:file=-" -f null - 2>/dev/null \
     | awk -F= '/lavfi.r128.S/{v=$2+0; if(!s||v>m){m=v;s=1}} END{if(s)printf "%.1f",m; else print "NA"}')
  PLR=$(python3 -c "print(round($TP-($I),1))" 2>/dev/null || echo NA)
  PSR=$(python3 -c "print(round($TP-($SMAX),1))" 2>/dev/null || echo NA)
  LO=$(bandrms "$f" "highpass=f=20,lowpass=f=120")
  MID=$(bandrms "$f" "highpass=f=500,lowpass=f=2000")
  HI=$(bandrms "$f" "highpass=f=4000,lowpass=f=16000")
  LC=$(ffmpeg -hide_banner -nostats -i "$f" -af \
     "lowpass=f=120,aphasemeter=video=0,ametadata=mode=print:key=lavfi.aphasemeter.phase:file=-" \
     -f null - 2>/dev/null | awk -F= '/phase/{s+=$2;n++} END{if(n)printf "%.3f",s/n; else print "NA"}')
  echo "$(basename "$f"),$I,$SMAX,$LRA,$TP,$PLR,$PSR,$LO,$MID,$HI,$LC" >> "$CSV"
  echo "  scanned: $(basename "$f")"
done
echo "-> $CSV"
command -v column >/dev/null 2>&1 && column -s, -t "$CSV" || cat "$CSV"
