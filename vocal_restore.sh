#!/bin/bash
# ============================================================
# Vocal Restoration Orchestrator
# ============================================================
# Restores SUNO-sourced vocals by:
#   1. Stem separation (delegated to open_DAW CLI)
#   2. Per-stage neural restoration (DeepFilterNet3 → VoiceFixer → Apollo)
#   3. Re-mix restored vocal + instrumental
#   4. Optional: hand off to existing vocal_prep.sh
#
# Usage:
#   bash vocal_restore.sh <input.wav_or_mp3> [<output_dir>]
#
# Environment toggles (default: all off except voicefixer):
#   VR_DEROOM=1      — run DeepFilterNet3 de-room stage
#   VR_VOICEFIXER=1  — run VoiceFixer mode 2 (default: 1)
#   VR_APOLLO=1      — run Apollo de-codec stage
#   VR_AUDIOSR=1     — run AudioSR 48k upsample (default: 0)
#   VR_VOCALPREP=1   — after remix, run vocal_prep.sh (default: 0)
#
# Requires open_DAW repo as sibling or OPEN_DAW_PATH env var.
# ============================================================
set -euo pipefail

INPUT="${1:-}"
OUT_DIR="${2:-${PWD}}"
OPEN_DAW_PATH="${OPEN_DAW_PATH:-${PWD}/../open_DAW}"

# Stage toggles
VR_DEROOM="${VR_DEROOM:-0}"
VR_VOICEFIXER="${VR_VOICEFIXER:-1}"
VR_APOLLO="${VR_APOLLO:-0}"
VR_AUDIOSR="${VR_AUDIOSR:-0}"
VR_VOCALPREP="${VR_VOCALPREP:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESTORE_DIR="${SCRIPT_DIR}/tools/vocal_restore"

# Make both the mastering_tool tools and the umbrella toolshop package importable.
UMBRELLA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
export PYTHONPATH="${SCRIPT_DIR}:${UMBRELLA_DIR}:${PYTHONPATH:-}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ -z "$INPUT" ]]; then
    echo "Usage: vocal_restore.sh <input.wav_or_mp3> [output_dir]"
    exit 1
fi

if [[ ! -f "$INPUT" ]]; then
    echo "Error: input not found: $INPUT"
    exit 1
fi

mkdir -p "$OUT_DIR"

BASENAME=$(basename "$INPUT" | sed 's/\.[^.]*$//')
REPORT="${OUT_DIR}/${BASENAME}_VOCAL_RESTORE_REPORT.md"

# ------------------------------------------------------------------
# 1. Stem separation via open_DAW CLI
# ------------------------------------------------------------------
echo "[vocal_restore] Stem separation…"

VOCAL_STEM="${OUT_DIR}/${BASENAME}_vocal.wav"
INST_STEM="${OUT_DIR}/${BASENAME}_instrumental.wav"

if [[ -f "$VOCAL_STEM" && -f "$INST_STEM" ]]; then
    echo "[vocal_restore] Re-using existing stems: $VOCAL_STEM, $INST_STEM"
else
    if [[ ! -d "$OPEN_DAW_PATH" ]]; then
        echo "Error: open_DAW not found at $OPEN_DAW_PATH"
        echo "Set OPEN_DAW_PATH or ensure open_DAW is a sibling directory."
        exit 1
    fi

    python -m ai_modules.stem_extractor.cli separate "$INPUT" \
        --backend roformer \
        --stem vocals,instrumental \
        > "${OUT_DIR}/${BASENAME}_stems.txt"

    # The CLI prints "vocals: /path/to/file.wav" lines; parse them.
    while IFS= read -r line; do
        key=$(echo "$line" | cut -d':' -f1 | tr -d ' ')
        val=$(echo "$line" | cut -d':' -f2- | sed 's/^ *//')
        if [[ "$key" == "vocals" ]]; then
            cp "$val" "$VOCAL_STEM"
        elif [[ "$key" == "instrumental" ]]; then
            cp "$val" "$INST_STEM"
        fi
    done < "${OUT_DIR}/${BASENAME}_stems.txt"
fi

# ------------------------------------------------------------------
# 2. Restoration chain
# ------------------------------------------------------------------
RESTORED_VOCAL="${OUT_DIR}/${BASENAME}_vocal_restored.wav"

STAGE_FLAGS=()
[[ "$VR_DEROOM" == "1" ]]    && STAGE_FLAGS+=("--stage" "deepfilter")
[[ "$VR_VOICEFIXER" == "1" ]] && STAGE_FLAGS+=("--stage" "voicefixer")
[[ "$VR_APOLLO" == "1" ]]    && STAGE_FLAGS+=("--stage" "apollo")
[[ "$VR_AUDIOSR" == "1" ]]   && STAGE_FLAGS+=("--stage" "audiosr")

if [[ ${#STAGE_FLAGS[@]} -eq 0 ]]; then
    echo "[vocal_restore] No restoration stages enabled; copying vocal as-is."
    cp "$VOCAL_STEM" "$RESTORED_VOCAL"
else
    echo "[vocal_restore] Running stages: ${STAGE_FLAGS[*]}"
    python "${RESTORE_DIR}/restore.py" \
        "$VOCAL_STEM" \
        "$RESTORED_VOCAL" \
        "${STAGE_FLAGS[@]}"
fi

# ------------------------------------------------------------------
# 3. Re-mix
# ------------------------------------------------------------------
RESTORED_MIX="${OUT_DIR}/${BASENAME}_restored_full_mix.wav"

echo "[vocal_restore] Re-mixing…"
python "${RESTORE_DIR}/remix.py" \
    --vocal "$RESTORED_VOCAL" \
    --instrumental "$INST_STEM" \
    --output "$RESTORED_MIX" \
    --gain-match lufs

# ------------------------------------------------------------------
# 4. Optional vocal_prep.sh polish
# ------------------------------------------------------------------
if [[ "$VR_VOCALPREP" == "1" && -f "${SCRIPT_DIR}/vocal_prep.sh" ]]; then
    echo "[vocal_restore] Running vocal_prep.sh…"
    bash "${SCRIPT_DIR}/vocal_prep.sh" "$RESTORED_MIX" "${OUT_DIR}/${BASENAME}_vocal_prep.wav"
fi

# ------------------------------------------------------------------
# 5. Report
# ------------------------------------------------------------------
cat > "$REPORT" <<EOF
# Vocal Restoration Report — ${BASENAME}

**Date:** ${TIMESTAMP}  
**Input:** \`$INPUT\`  
**Output directory:** \`$OUT_DIR\`

## Stages Enabled

| Stage | Env Var | Status |
|---|---|---|
| DeepFilterNet3 (de-room) | VR_DEROOM | $VR_DEROOM |
| VoiceFixer mode 2 (de-plastic) | VR_VOICEFIXER | $VR_VOICEFIXER |
| Apollo (de-codec) | VR_APOLLO | $VR_APOLLO |
| AudioSR (48k upsample) | VR_AUDIOSR | $VR_AUDIOSR |
| vocal_prep.sh polish | VR_VOCALPREP | $VR_VOCALPREP |

## Deliverables

| File | Description |
|---|---|
| \`$VOCAL_STEM\` | Isolated vocal stem |
| \`$INST_STEM\` | Isolated instrumental stem |
| \`$RESTORED_VOCAL\` | Restored vocal (post-chain) |
| \`$RESTORED_MIX\` | Restored vocal + instrumental remix |

## Chain Architecture

\`\`\`
input.wav
  │
  ├─ [open_DAW CLI] → vocal.wav + instrumental.wav  (Mel-Band RoFormer)
  │
  ├─ vocal.wav:
  │     ${VR_DEROOM:+├─ [DeepFilterNet3]  → de-room/de-noise\n}  │     ${VR_VOICEFIXER:+├─ [VoiceFixer mode 2] → de-plastic\n}  │     ${VR_APOLLO:+├─ [Apollo]           → de-codec / restore HF\n}  │     ${VR_AUDIOSR:+└─ [AudioSR]          → 48k SR\n}  │     └─ vocal_restored.wav
  │
  ├─ instrumental.wav: passthrough
  │
  └─ [remix.py] vocal_restored + instrumental → restored_full_mix.wav
\`\`\`

---
*Auto-generated by vocal_restore.sh*
EOF

echo "[vocal_restore] Done. Report: $REPORT"
