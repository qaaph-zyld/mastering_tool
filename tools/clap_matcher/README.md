# CLAP Reference Matching

Match a mastered track against the reference library using CLAP
(Contrastive Language-Audio Pretraining) embeddings.

## Installation

```bash
pip install -r tools/clap_matcher/requirements.txt
```

## Usage

```bash
# Compare a track against the reference library
python tools/clap_matcher/clap_matcher.py "mastered_track.wav"

# With options
python tools/clap_matcher/clap_matcher.py "mastered_track.wav" \
    --top-k 10 \
    --force-recompute
```

## How It Works

1. Load all references from `REFERENCE_LIBRARY.csv`
2. Compute CLAP audio embeddings for references (cached to `.clap_cache/`)
3. Compute CLAP embedding for the input track
4. Rank by cosine similarity
5. Write `CLAP_MATCH_REPORT.md`

## Model

- **Default**: `laion/clap-htsat-fused` (HuggingFace)
- **Size**: ~300MB on disk, ~150MB RAM footprint
- **Device**: CPU only (no CUDA required)

## Output Format

The report includes:
- Top-K matches with similarity scores
- Reference metadata (LUFS, LRA, true peak)
- Interpretation guidelines

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (track not found, model failure) |
