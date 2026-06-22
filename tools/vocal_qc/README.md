# Vocal QC — Whisper-Driven Quality Control

Transcribe vocal tracks with `faster-whisper`, detect artifacts, and flag
tracks that need manual review before mastering.

## Installation

```bash
pip install -r tools/vocal_qc/requirements.txt
```

## Usage

```bash
# Default: large-v3 int8 CPU
python tools/vocal_qc/vocal_qc.py "vocal_track.wav"

# With options
python tools/vocal_qc/vocal_qc.py "vocal_track.wav" \
    --model medium.en \
    --confidence 0.5 \
    --gap 1.5 \
    --language de
```

## Detected Artifacts

| Artifact | Trigger |
|----------|---------|
| `low_confidence` | Word confidence < threshold (default 0.6) |
| `missing_breath` | Gap between words > threshold (default 2.0s) |
| `long_gap` | Lead-in or tail silence > 1.0s |
| `pitch_drift` | Reserved for future `crepe` integration |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No artifacts detected |
| 2 | Artifacts found (flagged for review) |
| 1 | Error (file not found, model failure, etc.) |

## Hardware Budget

- **Default model**: `large-v3` with `int8` quantization (~1.5GB on CPU)
- **Fallback**: `medium.en` with `int8` (~800MB) if OOM on 8GB machine
- No GPU required; CTranslate2 handles CPU inference efficiently
