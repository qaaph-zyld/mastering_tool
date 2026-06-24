# Phase 8 Static Review — Mastering_Toolshop Phase 4/6/7a/7c

Reviewed: 2026-06-24
Scope: `tools/vocal_restore/`, `tools/vocal_qc/`, `tools/vocal_doctor/`, `tools/chain_dsl/`, `tools/clap_matcher/`

## Correctness

### 1. `vocal_restore.sh` + `tools/vocal_restore/`
- **Bash-only orchestrator**: `vocal_restore.sh` requires WSL/Git Bash on Windows. Fine for the 16 GB box, but not portable to PowerShell.
- **Stem separation assumes open_DAW CLI**: `python -m ai_modules.stem_extractor.cli separate` is real and parses `stem: path` output correctly.
- **Restore stage uses lazy import probes**: `restore.py` checks `_has("df.enhance")`, `_has("voicefixer")`, etc. and warns instead of hard-failing. This is good for CPU-only installs where some stages are skipped.
- **Apollo stage is a no-op**: `stage_apollo` only loads `transformers` and warns that the inference pipeline is not implemented. This is honest but means Apollo cannot be validated in Phase 8.
- **VoiceFixer resampling bug risk**: `librosa.resample(out.T, ...)` assumes stereo output; if `out.ndim == 1`, the earlier branch already handles it, so the `.T` path is safe for 2-D.

### 2. `tools/vocal_qc/`
- **CPU-friendly**: Defaults to `faster-whisper` `large-v3` int8 with `medium.en` fallback.
- **Artifact detection is rule-based and deterministic**: Low-confidence words, missing breaths, and long gaps are clearly defined.
- **Minor issue**: `get_audio_duration` uses the `wave` module first, which only supports WAV. MP3/FLAC inputs fall back to `ffprobe` — fine, but `ffprobe` must be on PATH.

### 3. `tools/vocal_doctor/`
- **Rule engine is transparent**: Every recommendation has rule, evidence, confidence, and chain action.
- **Import packaging smell**: `recommend.py` mixes absolute (`from mastering_tool.tools.chain_dsl.schema import ...`) and relative (`from .diagnose import diagnose_vocal`). This works only if the package is installed as `mastering_tool`. **Fix: make the `chain_dsl` import relative.**
- **External dependency**: `diagnose.py` imports `from toolshop.voice_effects_adapter import analyze_voice`. This requires the parent `music-ai-toolshop` package to be importable. Phase 8 packaging must include the parent repo on `PYTHONPATH` or install it.

### 4. `tools/chain_dsl/`
- **Schema is clean and round-trips**: YAML, JSON, and the flat MasterBus dict all work.
- **pedalboard executor matches real API**: `Compressor` omits unsupported `knee_db`; `Limiter` uses `threshold_db=ceiling_db` (pedalboard API). The de-esser fallback is a narrow peak cut — documented and honest.
- **MasterBus executor is lossy for de-esser**: documented in code and tests.

### 5. `tools/clap_matcher/`
- **Hardcoded paths**: `D:/Projects/Music-AI-Toolshop/Distro Kidea`, `D:/Projects/Music-AI-Toolshop/mastering_tool/.clap_cache`, and the default `REFERENCE_LIBRARY.csv` are all hardcoded. These will break on any other machine or CI runner.
- **Model**: `laion/clap-htsat-fused` CPU inference is reasonable for the 16 GB box.
- **Embedding cache**: Caching is implemented; useful for repeated validation runs.

### 6. Tests
- **Current mock counts** (actual): CLAP test has 3 `@patch` decorators, Vocal QC has 3 `@patch` decorators. The rule-engine tests are fully deterministic; Chain DSL tests use real `pedalboard` with synthetic audio.
- **Test file locations**: Tests live next to modules (`test_*.py`) rather than in a `tests/` directory. This is fine but inconsistent with the `vocal_restore/tests/` layout mentioned in some handoffs.

## Packaging

- No top-level `pyproject.toml` or `setup.py` exists in `mastering_tool`.
- `recommend.py` is the only file that references the `mastering_tool` namespace.
- `diagnose.py` depends on the umbrella `toolshop` package.

## Recommended fixes for Phase 8

1. Add `pyproject.toml` + `setup.py` to make `mastering_tool` an editable package.
2. Change `recommend.py` import to relative (`from ..chain_dsl.schema import ...`).
3. Make `clap_matcher.py` paths configurable via environment variables (`DISTRO_KIDEA_DIR`, `CLAP_CACHE_DIR`, `REFERENCE_LIBRARY_CSV`) with the current hardcoded values as defaults.
4. Ensure `vocal_restore.sh` sets `PYTHONPATH` to include both the parent `Music-AI-Toolshop` (for `toolshop`) and the current `mastering_tool` root.
5. Install CPU-only PyTorch and `onnxruntime` instead of GPU variants for the validation run.
