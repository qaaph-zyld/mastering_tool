#!/bin/bash
# ============================================================
# stage_clip_limit.sh  —  Stage E0 (soft-clip) -> E1 (true-peak limit)
# ------------------------------------------------------------
# DEFAULT (proven, true-peak compliant, deterministic):
#   E0: Airwindows ClipOnly2  (clips only overs, leaves the rest
#       bit-identical; 1-sample latency)
#   E1: alimiter inside a 4x soxr-oversampled scaffold (brickwall
#       true-peak). Verified COMPLIANT across input drive levels.
#
# WHY NOT THE LSP LIMITER BY DEFAULT:
#   Empirically the LSP limiter via lv2apply does NOT hold a true-
#   peak brickwall — with ovs=Full x4 it overshot the ceiling by
#   0.6-0.8 dB across boost/alr settings on hot input. It remains
#   available (USE_LSP_LIMITER=1) for non-critical use but is not
#   trusted for the true-peak guarantee. The alimiter 4x scaffold
#   is the limiter of record.
#
# Ceiling mapping: alimiter limit = dB->lin(ceiling - 0.4 dB), the
# 0.4 dB absorbing residual inter-sample peak (limit=0.85 -> ~-1.0
# dBTP, matching the reference pipeline's production result).
#
# Fallbacks preserved (never delete a stage):
#   E0_CLIPPER=lsp     -> LSP clipper instead of ClipOnly2
#   USE_LSP_LIMITER=1  -> LSP limiter E1 (overshoots; not for masters)
#
# Usage: bash stage_clip_limit.sh <in.wav> <out.wav>
# ============================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/family_policy.sh"

IN="$1"; OUT="$2"
[ -z "$OUT" ] && { echo "Usage: $0 <in.wav> <out.wav>"; exit 1; }

TP_DBTP="${CEILING_DBTP:-${TARGET_TP_DBTP:--1.0}}"
E0_CLIPPER="${E0_CLIPPER:-cliponly2}"
USE_LSP_LIMITER="${USE_LSP_LIMITER:-0}"
CLIP_HEADROOM_DB="${CLIP_HEADROOM_DB:-1.0}"
TPMARGIN_DB="${TPMARGIN_DB:-0.4}"
CLIPONLY2_URI="https://hannesbraun.net/ns/lv2/airwindows/cliponly2"
LSP_CLIP_URI="http://lsp-plug.in/plugins/lv2/clipper_stereo"
LSP_LIM_URI="http://lsp-plug.in/plugins/lv2/limiter_stereo"

SR=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$IN")
OS=$(python3 -c "print(192000 if $SR==48000 else 176400)")
db2lin () { python3 -c "print(10**($1/20))"; }
ALIM_LIMIT=$(db2lin "$(python3 -c "print($TP_DBTP - $TPMARGIN_DB)")")
TMP=$(mktemp -d)

if [ "$E0_CLIPPER" = "lsp" ]; then
  TH_CLIP=$(db2lin "$(python3 -c "print($TP_DBTP + $CLIP_HEADROOM_DB)")")
  lv2apply -i "$IN" -o "$TMP/e0.wav" -c ce 1 -c thresh "$TH_CLIP" -c ct 0.92 -c dither 0 "$LSP_CLIP_URI" 2>/dev/null
else
  lv2apply -i "$IN" -o "$TMP/e0raw.wav" "$CLIPONLY2_URI" 2>/dev/null
  ffmpeg -hide_banner -nostats -y -i "$TMP/e0raw.wav" -af "atrim=start_sample=1,asetpts=N/SR/TB" "$TMP/e0.wav" 2>/dev/null
fi

if [ "$USE_LSP_LIMITER" = "1" ]; then
  echo "[stage_clip_limit] WARNING: LSP limiter path can overshoot the true-peak ceiling; not for masters."
  TH_LIM=$(db2lin "$TP_DBTP")
  ffmpeg -hide_banner -nostats -y -i "$TMP/e0.wav" -af "apad=pad_len=2048" "$TMP/e0p.wav" 2>/dev/null
  lv2apply -i "$TMP/e0p.wav" -o "$TMP/e1p.wav" -c th "$TH_LIM" -c ovs 16 -c boost 0 -c alr 1 -c lk 5 -c rt 5 -c dith 0 "$LSP_LIM_URI" 2>/dev/null
  ffmpeg -hide_banner -nostats -y -i "$TMP/e1p.wav" -af "atrim=start_sample=372,asetpts=N/SR/TB" "$OUT" 2>/dev/null
else
  ffmpeg -hide_banner -nostats -y -i "$TMP/e0.wav" \
    -af "aresample=$OS:resampler=soxr:precision=28,alimiter=limit=$ALIM_LIMIT:level=disabled,aresample=$SR:resampler=soxr:precision=28" \
    "$OUT" 2>/dev/null
fi

TP=$(ffmpeg -hide_banner -nostats -i "$OUT" -af "ebur128=peak=true:framelog=quiet" -f null - 2>&1 | grep "Peak:" | tail -1 | awk '{print $2}')
COMPLY=$(python3 -c "print('COMPLIANT' if $TP<=$TP_DBTP else 'OVER')" 2>/dev/null || echo '?')
echo "[stage_clip_limit] E0=$E0_CLIPPER  E1=$([ "$USE_LSP_LIMITER" = 1 ] && echo LSP || echo alimiter-4x)  true peak = ${TP} dBFS (ceiling ${TP_DBTP} dBTP) [$COMPLY]"
rm -rf "$TMP"
