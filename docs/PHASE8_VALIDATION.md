# Phase 8 Integration & Validation Gate — Mastering_Toolshop

**Date:** 2026-06-24  
**Branch:** `claude/wonderful-johnson-h6xj4d`  
**Hardware:** Windows 10, 16 GB RAM, Intel CPU (no GPU), Python 3.13.5  
**Environment:** `d:\Projects\.venv` (CPU-only PyTorch + real heavy models)

## Objective

Run the full Phase 8 vocal chain on **3 real raw SUNO tracks**, save all artifacts, and fix any packaging/import/runtime issues surfaced by the end-to-end run.

## Tracks validated

| # | Source file (raw, non-mastered) | 30 s clip | Output dir |
|---|-------------------------------|-----------|------------|
| 1 | `Pod Senkom Breze_Hardcore_Pop_2.mp3` | `phase8_artifacts/clip1.mp3` | `phase8_artifacts/track1_Pod_Senkom_Breze` |
| 2 | `Love Language_Hardcore_Pop_1.mp3` | `phase8_artifacts/clip2.mp3` | `phase8_artifacts/track2_Love_Language` |
| 3 | `Overthinkk_Hardcore_Pop_2.mp3` | `phase8_artifacts/clip3.mp3` | `phase8_artifacts/track3_Overthinkk` |

*30-second clips were extracted with `ffmpeg -t 30 -c copy` to keep CPU runtime manageable while still using real audio and real models.*

## Chain run

```text
vocal_restore  -> vocal_qc -> vocal_doctor -> chain_dsl -> clap_matcher
```

### 1. Stem separation

- **Tool:** `open_DAW.ai_modules.stem_extractor` via `audio-separator` 0.44.2
- **Model:** Mel-Band RoFormer vocals (`vocals_mel_band_roformer.ckpt`, ~913 MB)
- **Fix applied:** Models are now cached persistently in `~/.opendaw/models` instead of a temp directory, so the 913 MB checkpoint is downloaded once.
- **Fix applied:** Stem separator output paths were made absolute before caching; the relative filenames returned by `audio-separator` caused `FileNotFoundError` in the stem cache.
- **Instrumental:** derived as `mix - vocal` after resampling to the same sample rate.

### 2. Vocal restoration

- **Tool:** `voicefixer` mode 2 (CPU, `cuda=False`)
- **Fix applied:** VoiceFixer processes non-overlapping 30-second segments at 44100 Hz and crashes when the final segment is only a few samples long. `tools/vocal_restore/restore.py::stage_voicefixer` now resamples to 44100 Hz and trims to a whole multiple of 30 seconds before inference.

### 3. Re-mix

- **Tool:** `tools/vocal_restore/remix.py`
- **Fix applied:** The restored vocal is at 44100 Hz while the instrumental derived from the original MP3 is at 48000 Hz. The validation script now resamples the restored vocal to the instrumental rate before summing.
- **Result:** All 3 remixed files wrote successfully; gain-matching attenuated peaks > 0 dBFS.

### 4. Vocal QC

- **Tool:** `tools/vocal_qc/vocal_qc.py` with `faster-whisper` `base.en` int8
- **Fix applied:** Disabled HuggingFace symlinks (`HF_HUB_DISABLE_SYMLINKS=1`) on Windows to avoid `[WinError 1314]` privilege errors during model download.

| Track | Flagged | Artifacts |
|-------|---------|-----------|
| 1 Pod Senkom Breze | True | 19 |
| 2 Love Language | True | 14 |
| 3 Overthinkk | True | 10 |

### 5. Vocal Doctor

- **Tool:** `tools/vocal_doctor/recommend.py`
- All 3 tracks produced chain recommendations and wrote `chain.json` + `vocal_doctor.json`.

| Track | Recommendations |
|-------|-----------------|
| 1 Pod Senkom Breze | 6 |
| 2 Love Language | 5 |
| 3 Overthinkk | 6 |

### 6. Chain DSL render

- **Tool:** `tools/chain_dsl/executors/pedalboard_exec.py`
- All 3 tracks rendered the Vocal Doctor chain through `pedalboard` and produced `_chain_rendered.wav` files.

### 7. CLAP reference match

- **Tool:** `tools/clap_matcher/clap_matcher.py`
- **Model:** `laion/clap-htsat-fused`
- **Fix applied:** `processor(audios=...)` changed to `processor(audio=...)` for current `transformers`.
- **Fix applied:** `model.get_audio_features()` now extracts `pooler_output` when the newer `transformers` returns a model-output object instead of a raw tensor.
- **Fix applied:** `REFERENCE_LIBRARY.csv` is read with `utf-8-sig` encoding to strip the leading BOM that corrupted the `name` field.
- **Fix applied:** `CLAP_CACHE_DIR` cleaned of stale/corrupted embeddings before re-run.

| Track | Top match | Similarity |
|-------|-----------|------------|
| 1 Pod Senkom Breze | `Slap_MASTER_32f` | 0.871 |
| 2 Love Language | `BUDI_JAK_1_17_05_MASTER_32f` | 0.773 |
| 3 Overthinkk | `Keine_Zeit_zu_Verlieren_MASTER_32f` | 0.772 |

## Runtime summary (per 30-second clip)

| Track | Stem separation | VoiceFixer | Remix | QC | Doctor | Pedalboard | CLAP | Total |
|-------|-----------------|------------|-------|-----|--------|------------|------|-------|
| 1 | 0.0 s (cached) | 61.9 s | 0.8 s | 42.8 s | 47.6 s | 0.4 s | 16.4 s | ~169 s |
| 2 | 153.4 s | 54.4 s | 0.7 s | 52.2 s | 50.4 s | 0.4 s | 36.8 s | ~348 s |
| 3 | 163.4 s | 61.4 s | 0.6 s | 21.7 s | 55.2 s | 0.6 s | 34.5 s | ~336 s |

*Track 1 stem separation was cached from the previous clip1_run8 run.*

## Artifacts produced

Each track output directory contains:

- `<basename>_vocal.wav`
- `<basename>_instrumental.wav`
- `<basename>_vocal_restored.wav`
- `<basename>_restored_full_mix.wav`
- `<basename>_chain_rendered.wav`
- `chain.json`
- `vocal_doctor.json`
- `VOCAL_QC_REPORT.md`
- `CLAP_MATCH_REPORT.md`
- `phase8_summary.json`
- `<basename>_validation.log`

## Bugs fixed during validation

| File | Problem | Fix |
|------|---------|-----|
| `open_DAW/ai_modules/stem_extractor/separator.py` | Model re-downloaded on every run; output paths relative | Persistent `~/.opendaw/models` cache; absolute output paths |
| `open_DAW/ai_modules/stem_extractor/cache.py` (caller) | N/A | Already worked once paths were absolute |
| `mastering_tool/tools/vocal_restore/restore.py` | VoiceFixer STFT crash on short final segment | Trim to whole 30-second segments at 44100 Hz |
| `mastering_tool/phase8_validate.py` | Sample-rate mismatch between restored vocal and instrumental | Resample vocal to instrumental rate before remix |
| `mastering_tool/phase8_validate.py` | HF symlink errors on Windows | Set `HF_HUB_DISABLE_SYMLINKS=1` |
| `mastering_tool/tools/clap_matcher/clap_matcher.py` | `processor(audios=...)` deprecated | Use `processor(audio=...)` |
| `mastering_tool/tools/clap_matcher/clap_matcher.py` | `get_audio_features` returns model output object | Extract `pooler_output` |
| `mastering_tool/tools/clap_matcher/clap_matcher.py` | BOM in CSV corrupts `name` field | Read with `utf-8-sig` |

## Packaging / environment

- `pyproject.toml` and `setup.py` in `mastering_tool/` enable editable install.
- `vocal_doctor/recommend.py` import was made relative.
- `clap_matcher.py` paths are now configurable via `DISTRO_KIDEA_DIR`, `CLAP_CACHE_DIR`, `REFERENCE_LIBRARY_CSV`.
- `vocal_restore.sh` exports `PYTHONPATH` including the umbrella repo and `mastering_tool` root.
- All CPU dependencies were installed and verified: `torch`, `torchaudio`, `transformers`, `faster-whisper`, `deepfilternet`, `voicefixer`, `audio-separator`, `pedalboard`, `librosa`, `soundfile`.

## Notes

- The `audio-separator` instrumental model was intentionally avoided by deriving the instrumental as `mix - vocal`; this halves model-download time and keeps the 16 GB CPU box within budget.
- Full-length tracks would take ~8–12× longer per track; the 30-second clips are sufficient to exercise every real model in the chain.
- No OOM occurred during validation; peak working set stayed within the 16 GB budget.

## Status

**Phase 8 Track A validation passed for 3 raw SUNO tracks.**

Remaining work:
- De-mock cheap CPU tests.
- Push Track A commits.
- Verify Track B open_DAW CI workflow is green.
