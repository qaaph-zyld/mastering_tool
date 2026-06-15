#!/bin/bash
# ============================================================
# master_pipeline_v3.sh  —  integrated mastering pipeline
# ------------------------------------------------------------
# Orchestrates the upgraded chain. Stages A/B/C preserve the
# established FFmpeg approach; D and E are upgraded to the new
# modular LV2 stages; conditional multiband and an MP3-path E2
# limiter are added; QC + translation run at the end.
#
#   A  prep        : headroom / DC / 25 Hz HPF        (FFmpeg)
#   B  EQ          : parametric                        (FFmpeg)
#   C  glue comp   : acompressor                       (FFmpeg)
#   C2 multiband   : LSP mb_compressor   [conditional, gated]
#   D  low-end     : policy widening + bass-mono       (modules)
#   E0 soft-clip   : ClipOnly2 / LSP clipper           (module)
#   E1 limit       : LSP true-peak limiter             (module)
#   F  deliverables: 32f / 16-bit TPDF / 320 MP3 (+E2 ceiling)
#   QC verify + translation matrix + audio MD5
#
# Framework rules: never delete a stage (conditional-disable),
# parameterized, retained intermediates, MD5 determinism, full
# report. Old pipeline kept as master_pipeline_REFERENCE.sh.
#
# Usage: bash master_pipeline_v3.sh <source.wav> <name> [project_dir] [profile]
# ============================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/family_policy.sh"

SOURCE="$1"; NAME="${2:-master}"; PROJECT_DIR="${3:-.}"; PROFILE="${4:-}"
[ -z "$SOURCE" ] && { echo "Usage: $0 <source.wav> <name> [project_dir] [profile]"; exit 1; }
[ -n "$PROFILE" ] && eval "$(policy_profile "$PROFILE")" && eval "$(policy_genre_presets "$PROFILE")" && echo ">>> profile: $PROFILE -> $TARGET_LUFS LUFS / $TARGET_TP_DBTP dBTP"

ANA="$PROJECT_DIR/analysis"; INT="$PROJECT_DIR/intermediate"
OUT="$PROJECT_DIR/master"; VER="$PROJECT_DIR/verification"
mkdir -p "$ANA" "$INT" "$OUT" "$VER"

# ---- per-track calibration parameters (bracket pre-gain per source) ----
PREGAIN_DB="${PREGAIN_DB:-6.3}"        # MUST be bracketed per track (undershoots from formula)
MULTIBAND_ENABLE="${MULTIBAND_ENABLE:-0}"
EQ_CHAIN="${EQ_CHAIN:-equalizer=f=200:t=q:w=1.2:g=-1.5,equalizer=f=80:t=q:w=1.4:g=0.8,equalizer=f=3500:t=q:w=1.5:g=0.6,equalizer=f=12000:t=q:w=0.7:g=1.5}"
COMP="${COMP:-acompressor=threshold=-16dB:ratio=1.8:attack=20:release=180:makeup=1.5:knee=4}"
MP3_CEIL="${MP3_CEIL:-0.82}"           # E2 lower ceiling for MP3 path (calibrate per source)

echo ">>> Source: $SOURCE   target ${TARGET_LUFS} LUFS / ${TARGET_TP_DBTP} dBTP"

# --- pre-master diagnostic (measure before processing) ---
echo "[*] Pre-master diagnostic"
bash "$HERE/premaster_diagnostic.sh" "$SOURCE" "$ANA/premaster_diagnostic.txt" >/dev/null

# --- STAGE A: prep ---
echo "[A] Headroom / DC / HPF 25Hz"
ffmpeg -hide_banner -nostats -y -i "$SOURCE" \
  -af "volume=-6dB,dcshift=0.0004,highpass=f=25:poles=2" -c:a pcm_f32le "$INT/01_prep.wav" 2>/dev/null

# --- STAGE B: EQ ---
echo "[B] Parametric EQ"
ffmpeg -hide_banner -nostats -y -i "$INT/01_prep.wav" -af "$EQ_CHAIN" -c:a pcm_f32le "$INT/02_eq.wav" 2>/dev/null

# --- STAGE C: glue comp ---
echo "[C] Glue compression"
ffmpeg -hide_banner -nostats -y -i "$INT/02_eq.wav" -af "$COMP" -c:a pcm_f32le "$INT/03_comp.wav" 2>/dev/null
CUR="$INT/03_comp.wav"

# --- STAGE C2: multiband (conditional) ---
if [ "$MULTIBAND_ENABLE" = "1" ]; then
  echo "[C2] Multiband compressor (conditional)"
  bash "$HERE/lv2_stage.sh" "$CUR" "$INT/03b_mb.wav" "http://lsp-plug.in/plugins/lv2/mb_compressor_stereo"
  CUR="$INT/03b_mb.wav"
else
  echo "[C2] multiband: disabled (policy default)"
fi

# --- STAGE D: policy widening + bass-mono ---
echo "[D] Low-end / stereo (policy-driven)"
CORR_MIN=$(policy_corr_min_from_report "$ANA/premaster_diagnostic.txt")
WIDEN=$(policy_decide_widening "$CORR_MIN")
if [ "$WIDEN" = "ALLOW" ]; then
  M="${WIDEN_M:-1.10}"; echo "    widening ALLOW (corr_min=$CORR_MIN) -> extrastereo m=$M"
else
  M="$WIDENING_EXTRASTEREO_M"; echo "    widening SKIP (corr_min=$CORR_MIN) -> extrastereo m=$M (inert)"
fi
ffmpeg -hide_banner -nostats -y -i "$CUR" -af "extrastereo=m=$M,volume=-3dB" -c:a pcm_f32le "$INT/04_stereo.wav" 2>/dev/null
CUR="$INT/04_stereo.wav"
if [ "$BASS_MONO_ENABLE" = "1" ]; then
  echo "    bass-mono ENABLED @ ${BASS_MONO_FREQ}Hz"
  bash "$HERE/stage_bass_mono.sh" "$CUR" "$INT/04b_bassmono.wav" "$BASS_MONO_FREQ" >/dev/null
  CUR="$INT/04b_bassmono.wav"
fi

# --- STAGE E: pre-gain -> clip -> true-peak limit ---
echo "[E] Pre-gain ${PREGAIN_DB}dB -> clip -> true-peak limit (${TARGET_TP_DBTP} dBTP)"
ffmpeg -hide_banner -nostats -y -i "$CUR" -af "volume=${PREGAIN_DB}dB" -c:a pcm_f32le "$INT/05_pregain.wav" 2>/dev/null
CEILING_DBTP="$TARGET_TP_DBTP" bash "$HERE/stage_clip_limit.sh" "$INT/05_pregain.wav" "$INT/06_limited.wav"

# --- F: deliverables ---
echo "[F] Deliverables"
cp "$INT/06_limited.wav" "$OUT/${NAME}_MASTER_32f.wav"
ffmpeg -hide_banner -nostats -y -i "$INT/06_limited.wav" \
  -af "aresample=osf=s16:dither_method=triangular_hp" -c:a pcm_s16le "$OUT/${NAME}_MASTER_16.wav" 2>/dev/null
# E2: tighter-ceiling limiter feeding the MP3 path (content-dependent overshoot)
ffmpeg -hide_banner -nostats -y -i "$INT/06_limited.wav" \
  -af "alimiter=limit=${MP3_CEIL}:level=disabled" -c:a pcm_f32le "$INT/06e2_mp3src.wav" 2>/dev/null
ffmpeg -hide_banner -nostats -y -i "$INT/06e2_mp3src.wav" \
  -c:a libmp3lame -b:a 320k -compression_level 0 "$OUT/${NAME}_MASTER.mp3" 2>/dev/null

# --- determinism + QC ---
echo "[QC] audio MD5 + verify + translation"
for f in "$OUT/${NAME}_MASTER_32f.wav" "$OUT/${NAME}_MASTER_16.wav"; do
  md5=$(ffmpeg -hide_banner -i "$f" -map 0:a -f md5 - 2>/dev/null | sed 's/MD5=//')
  echo "$md5  $(basename "$f")" >> "$VER/determinism_md5.txt"
done
bash "$HERE/qc_verify.sh" "$OUT/${NAME}_MASTER_16.wav" "$VER/qc" "$TARGET_TP_DBTP" >/dev/null
bash "$HERE/qc_translation.sh" "$OUT/${NAME}_MASTER_16.wav" "$VER/translation" >/dev/null

echo ""
echo "============ DONE ============"
echo "  master/        : 32f, 16-bit, 320 MP3"
echo "  verification/  : determinism_md5.txt, qc/, translation/"
grep -E 'PSR GATE|true peak' "$VER/qc/qc_report.txt" 2>/dev/null | sed 's/^/  /'
grep 'VERDICT' "$VER/translation/"*/dev/null 2>/dev/null || true
