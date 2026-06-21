#!/bin/bash
# ============================================================
# qc_verify.sh  —  post-master QC gate (open-source, scriptable)
# ------------------------------------------------------------
# Produces, for a finished master:
#   1. Spectrogram PNG (showspectrumpic)
#   2. Loudness block: integrated LUFS, max short-term LUFS, LRA,
#      true peak; derived PLR and PSR estimate.
#   3. Codec round-trip true-peak re-check: encodes to AAC (native,
#      GPL-clean), Opus (libopus), MP3 (libmp3lame), decodes back,
#      re-measures true peak, and FLAGS any post-decode overshoot
#      above the ceiling (lossy encoders reconstruct inter-sample
#      peaks above the WAV ceiling).
#
# PSR/PLR notes (AES e-Brief 373 micro-dynamics):
#   PLR = TruePeak(dBTP) - Integrated(LUFS)
#   PSR ~= TruePeak(dBTP) - MaxShortTerm(LUFS)   [loudest-section estimate]
#   Gate: PSR >= 8 in the loudest section is the plan's red-line.
#
# Usage: bash qc_verify.sh <master.wav> <outdir> [ceiling_dbtp]
# ============================================================
set -e
SRC="$1"; OUT="${2:-qc_out}"; CEIL="${3:--1.0}"
[ -z "$SRC" ] && { echo "Usage: $0 <master.wav> <outdir> [ceiling_dbtp]"; exit 1; }
mkdir -p "$OUT"
REPORT="$OUT/qc_report.txt"

{
echo "============================================================"
echo " POST-MASTER QC GATE"
echo " Master: $SRC"
echo " Ceiling: $CEIL dBTP    Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================================"

# --- 1. Spectrogram ---
ffmpeg -hide_banner -nostats -y -i "$SRC" \
  -lavfi "showspectrumpic=s=1920x1080:legend=1" "$OUT/spectrogram.png" 2>/dev/null
echo ""
echo "[1] Spectrogram -> $OUT/spectrogram.png"

# --- 2. Loudness / dynamics ---
echo ""
echo "[2] LOUDNESS / DYNAMICS"
EBU=$(ffmpeg -hide_banner -nostats -i "$SRC" -af "ebur128=peak=true:framelog=quiet" -f null - 2>&1)
I=$(echo "$EBU"   | grep -E "^\s*I:"   | tail -1 | awk '{print $2}')
LRA=$(echo "$EBU" | grep -E "^\s*LRA:" | head -1 | awk '{print $2}')
TP=$(echo "$EBU"  | grep -E "Peak:"    | tail -1 | awk '{print $2}')
# max short-term via per-frame metadata (metadata=1 required to expose r128.S)
SMAX=$(ffmpeg -hide_banner -nostats -i "$SRC" \
  -af "ebur128=peak=true:metadata=1,ametadata=mode=print:key=lavfi.r128.S:file=-" -f null - 2>/dev/null | \
  awk -F= '/lavfi.r128.S/{v=$2+0; if(!seen||v>m){m=v;seen=1}} END{if(seen)printf "%.1f",m; else print "NA"}')
PLR=$(python3 -c "print(round($TP-($I),1))" 2>/dev/null || echo NA)
PSR=$(python3 -c "print(round($TP-($SMAX),1))" 2>/dev/null || echo NA)
printf "  integrated     : %s LUFS\n" "$I"
printf "  max short-term : %s LUFS\n" "$SMAX"
printf "  LRA            : %s LU\n"   "$LRA"
printf "  true peak      : %s dBFS\n" "$TP"
printf "  PLR            : %s\n"      "$PLR"
printf "  PSR (estimate) : %s   [gate: >= 8 in loudest section]\n" "$PSR"
python3 -c "import sys; sys.exit(0 if $PSR>=8 else 1)" 2>/dev/null \
  && echo "  PSR GATE       : PASS" || echo "  PSR GATE       : REVIEW (below 8 -> check loudest section)"

# --- Loudness acceptance gate ---
TARGET_LUFS="${TARGET_LUFS:--10.0}"
LUFS_OK=$(python3 -c "print('PASS' if abs($I - $TARGET_LUFS) <= 0.5 else 'FAIL')")
printf "  LUFS GATE      : %s   [target %.1f, measured %s, tolerance ±0.5 LU]\n" "$LUFS_OK" "$TARGET_LUFS" "$I"
if [ "$LUFS_OK" = "FAIL" ]; then
    echo "  ** LOUDNESS GATE FAIL: ${I} LUFS vs target ${TARGET_LUFS} LUFS — remaster required **"
fi

# --- 3. Codec round-trip true-peak re-check ---
echo ""
echo "[3] CODEC ROUND-TRIP TRUE-PEAK RE-CHECK (ceiling $CEIL dBTP)"
roundtrip () {  # $1=label $2=ext $3...=encode-args ; reads $SRC
    local label="$1"; local ext="$2"; shift 2
    local enc="$OUT/rt_$label"
    ffmpeg -hide_banner -nostats -y -i "$SRC" "$@" "$enc.$ext" 2>/dev/null || { printf "  %-12s ENCODE FAILED\n" "$label"; return 0; }
    ffmpeg -hide_banner -nostats -y -i "$enc.$ext" -c:a pcm_f32le "$enc.wav" 2>/dev/null
    local tp
    tp=$(ffmpeg -hide_banner -nostats -i "$enc.wav" -af "ebur128=peak=true:framelog=quiet" \
         -f null - 2>&1 | grep "Peak:" | tail -1 | awk '{print $2}')
    local flag
    flag=$(python3 -c "print('OVERSHOOT' if $tp>$CEIL else 'ok')" 2>/dev/null || echo '?')
    printf "  %-12s post-decode TP = %6s dBFS   [%s]\n" "$label" "$tp" "$flag"
}
roundtrip "AAC-256"  m4a  -c:a aac -b:a 256k
roundtrip "Opus-160" opus -c:a libopus -b:a 160k
roundtrip "MP3-320"  mp3  -c:a libmp3lame -b:a 320k -compression_level 0

echo ""
echo "============================================================"
echo " END QC GATE"
echo "============================================================"
} | tee "$REPORT"
