# Reverse Engineering Audit — `track_inventory/track_reverse_engineering`

**Date:** 2026-06-22
**Scope:** audit the local `wav_reverse_engineer` package for reuse in the Music-AI-Toolshop umbrella. Decisions are fixed per session plan: *extract subset, not submodule, not hard dependency*.

---

## What the RE repo is

A standalone audio-analysis package (`wav_reverse_engineer`) with:

- `audio_processor.py` — loading, resampling, normalizing, trimming, saving.
- `feature_extractor.py` — comprehensive librosa features: basic, spectral, rhythmic, harmonic, chord detection, key/mode.
- `effects_analyzer.py` — RT60 (EDC), spectral tilt, THD, compression index, LUFS/LRA via `pyloudnorm`.
- `source_separation.py` — HPSS (no deps), optional spleeter/demucs (heavy).
- `voice_effects_adapter.py` equivalent — **not present here**; the umbrella's `toolshop/voice_effects_adapter.py` is stronger for vocal diagnostics.
- `instrument_recognizer.py` — small classifier wrapper, currently lightweight.
- `backends/` — optional heavy integrations: `demucs`, `torchcrepe`, `basic_pitch`, `essentia`, `chordino`.
- `cli.py` + `webapp/` + `api/` — standalone user interfaces.
- `tests/` — unit tests for `effects_analyzer`, backends (mostly import/contract checks).
- License: MIT.

---

## Overlap with umbrella tools

| Capability | Umbrella location | RE location | Verdict |
|---|---|---|---|
| BPM / key | `toolshop/bpm_adapter.py` | `feature_extractor.py` | Umbrella is sufficient; RE is redundant. |
| Track structure | `toolshop/reverse_engineering_adapter.py` | `feature_extractor.py` | Umbrella is "pure librosa, no external repos"; RE is richer but heavier. |
| Vocal effect detection | `toolshop/voice_effects_adapter.py` (12 detectors) | (none) | Umbrella is the diagnostic engine for Vocal Doctor. |
| Loudness (LUFS/LRA) | **missing** | `effects_analyzer.py` | **Port.** Dependency-light (`pyloudnorm`), high value for QC. |
| RT60 (EDC) | partial in `voice_effects_adapter.detect_reverb()` | `effects_analyzer.estimate_rt60()` | **Port.** More rigorous EDC-based method. |
| Spectral tilt | **missing** | `effects_analyzer.spectral_tilt()` | **Port.** Useful for vocal brightness diagnostics. |
| THD | partial in `voice_effects_adapter.detect_distortion()` | `effects_analyzer.harmonic_distortion()` | **Port.** Cleaner harmonic-distortion formulation. |
| Compression index | partial (crest factor) | `effects_analyzer.compression_index()` | Consider porting as a secondary metric, not primary. |
| Chord detection | `reverse_engineering_adapter.py` (basic) | `feature_extractor.py` | Keep in RE; umbrella version is adequate. |
| Instrument recognition | **missing** | `instrument_recognizer.py` | Keep in RE; evaluate later if needed. |
| YouTube ingestion | `toolshop/yt_scraper_adapter.py` | `youtube_ingestion.py` | Keep in RE; umbrella has equivalent tools. |
| Source separation | Phase 1 STUB in `open_DAW` | `source_separation.py` | Keep in RE; stem extraction is the Phase 1 responsibility. |
| Heavy backends | none | `backends/` (torch/demucs/etc.) | Keep in RE; avoid heavy deps in umbrella. |

---

## Integration decision: extract subset

A git submodule or `pip install -e` would re-couple the umbrella to the RE repo and drag in heavy optional dependencies (`torch`, `demucs`, `spleeter`, `essentia`, `basic_pitch`). The umbrella explicitly *decoupled* from external repos (`reverse_engineering_adapter.py` is "pure librosa, no external repos"). Re-coupling is a step backward.

Instead, we surgically port the **dependency-light, genuinely missing** metrics into the umbrella:

1. `loudness_metrics()` — integrated LUFS and LRA via `pyloudnorm`.
2. `estimate_rt60()` — EDC-based RT60.
3. `spectral_tilt()` — dB-per-decade slope.
4. `harmonic_distortion()` — THD ratio.

These functions are self-contained (librosa/numpy only, plus `pyloudnorm` which is already in RE's install list and lightweight). They will live in a new umbrella module, e.g. `toolshop/audio_metrics.py` or `mastering_tool/tools/chain_dsl/audio_metrics.py`, with attribution comments referencing the RE source.

The RE repo keeps its standalone role: YouTube CLI/API, webapp, heavy backends, and full catalogue analysis. If a deeper integration is needed later (e.g., instrument recognition), it can be evaluated as a separate, scoped task.

---

## Recommended port list for this session

Port only the four functions above. Do not port:

- `AudioProcessor` (umbrella has librosa loading patterns).
- `FeatureExtractor` (overlap with `bpm_adapter` / `reverse_engineering_adapter`).
- `source_separation.py` (wait for Phase 1 stem separator).
- `instrument_recognizer.py` (not needed for Vocal Doctor v1).
- `backends/` (heavy deps).
- CLI / webapp / API surfaces (keep in RE repo).

---

## Test status

`tests/test_effects_analyzer.py` exists and is a basic contract test. It does not assert numerical correctness. When porting, we will add our own regression tests with synthetic signals (known LUFS on a sine wave, known RT60 on synthetic exponential decay, etc.) to ensure correctness.

## Risk notes

- `pyloudnorm` is not in the umbrella's `pyproject.toml` yet. Adding it is a small dependency (BSD/MIT family); verify license before pinning.
- The RE `effects_analyzer.py` assumes mono float input. The port must accept both mono and stereo and handle channel shape consistently.
- RT60 estimation on short pop vocals is noisy; use it as a *feature*, not a hard decision.
