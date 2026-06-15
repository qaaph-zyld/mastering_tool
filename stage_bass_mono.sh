#!/bin/bash
# ============================================================
# stage_bass_mono.sh  —  Stage D: phase-coherent bass-mono
# ------------------------------------------------------------
# Collapses low end to mono below a cutoff while preserving the
# stereo image above it. Avoids the image-twist of a differential
# side HPF by filtering L and R with the SAME (common-mode) high-
# pass, then adding back a mono-summed low-passed bass:
#
#     L_out = HP(L) + LP( (L+R)/2 )
#     R_out = HP(R) + LP( (L+R)/2 )
#
# HP and LP are complementary 4th-order Linkwitz-Riley (cascaded
# biquads). Common-mode HP => stereo image above cutoff preserved.
# Low path is mono by construction. Fully FFmpeg-native, no LV2,
# deterministic.
#
# Gated by family_policy.sh: runs only when policy permits and
# BASS_MONO_ENABLE=1. Default policy leaves master output unchanged.
#
# Usage: bash stage_bass_mono.sh <in.wav> <out.wav> [cutoff_hz]
# ============================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/family_policy.sh" ] && . "$HERE/family_policy.sh"

IN="$1"; OUT="$2"; F="${3:-${BASS_MONO_FREQ:-110}}"
[ -z "$OUT" ] && { echo "Usage: $0 <in.wav> <out.wav> [cutoff_hz]"; exit 1; }

ffmpeg -hide_banner -nostats -y -i "$IN" -filter_complex "
[0:a]asplit=2[st][mo];
[mo]pan=mono|c0=0.5*FL+0.5*FR,lowpass=f=${F}:poles=2,lowpass=f=${F}:poles=2,asplit=2[loA][loB];
[st]channelsplit=channel_layout=stereo[Lc][Rc];
[Lc]highpass=f=${F}:poles=2,highpass=f=${F}:poles=2[Lhp];
[Rc]highpass=f=${F}:poles=2,highpass=f=${F}:poles=2[Rhp];
[Lhp][loA]amix=inputs=2:weights=1 1:normalize=0[Lout];
[Rhp][loB]amix=inputs=2:weights=1 1:normalize=0[Rout];
[Lout][Rout]join=inputs=2:channel_layout=stereo[out]
" -map "[out]" -c:a pcm_f32le "$OUT" 2>/dev/null

echo "[stage_bass_mono] cutoff=${F}Hz  $IN -> $OUT"
