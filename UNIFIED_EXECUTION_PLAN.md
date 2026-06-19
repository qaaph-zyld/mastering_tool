# Unified Execution Plan — mastering_tool + open_DAW

**Plan owner:** human (qaaph-zyld)
**Plan executor:** AI IDE (this document is the brief)
**Scope:** two repos working as one toolkit
**Created:** 2026-06-19
**Status:** READY FOR EXECUTION

---

## 0. North Star

We are building an in-house production toolkit for SUNO-sourced music. Two repos, one product:

- **`mastering_tool/`** — finishing room. Deterministic FFmpeg pipeline, per-track tuning, reference benchmarking, QC. Currently the workhorse. Already produces shipping masters.
- **`open_DAW/`** — composition / arrangement room. Rust audio engine (53 tests, FFI green), JUCE C++ UI, Python AI bridge (currently stubs). Not yet shipping work.

These will be unified along **three integration seams**:

1. **Stem-aware vocal restoration** — `open_DAW`'s stem separator becomes the front stage of `mastering_tool`'s vocal chain. Single highest-value move.
2. **Mastering chain as `open_DAW`'s master bus** — the bash pipeline becomes auditionable in real time during mixing, not only after bounce.
3. **Plugin runtime (Neutone)** — `open_DAW`'s JUCE host loads neural-model plugins (RAVE, DDSP, custom). The plugins are also callable from `mastering_tool` as LV2/CLI.

**Constraints from the human:**
- Prefer existing open-source. Code only when nothing fits.
- SUNO vocal artifacts (metallic sibilance, emptiness, flat dynamics, breath gating, plastic timbre) are the priority pain point.
- Deterministic, reproducible, A/B-able. Same discipline as the existing pipeline.

---

## 1. Cross-repo dependency map

| Capability | Repo | Module / Path | Status |
|---|---|---|---|
| Deterministic FFmpeg master chain | `mastering_tool` | `master_pipeline*.sh` | mature |
| Pre-master diagnostic | `mastering_tool` | `premaster_diagnostic.sh` | mature |
| Reference benchmarking | `mastering_tool` | `reference_benchmark.sh`, `REFERENCE_LIBRARY.csv` | mature |
| Mix-level vocal prep | `mastering_tool` | `vocal_prep.sh` | mature, blunt (no stem isolation) |
| Matchering cross-check | `mastering_tool` | `matchering_xcheck.py` | mature, diagnostic-only |
| Web UI (Flask) | `mastering_tool` | `ui/server.py` | functional |
| Rust audio engine | `open_DAW` | `daw-engine/src/*.rs` | 53 tests passing |
| JUCE UI + FFI | `open_DAW` | `ui/src/*` | Phase 9.x green |
| Stem extractor | `open_DAW` | `ai_modules/stem_extractor/__init__.py` | **STUB — TODO Demucs** |
| ACE-Step bridge | `open_DAW` | `ai_modules/ace_step_bridge/__init__.py` | **STUB — TODO ACE-Step API** |
| Suno library browser | `open_DAW` | `ai_modules/suno_library/__init__.py` | **STUB — hard-coded test data** |

**The AI modules in `open_DAW` are real Python skeletons with `is_available()` checks but no working backend.** This plan replaces the stubs with production implementations.

---

## 2. Execution order (read this before anything else)

Phases are sequenced so each can be merged independently. Each phase has its own acceptance gate; do not proceed to the next phase until the previous one passes its A/B test.

```
Phase 0 — Catalogue hygiene (mastering_tool)        [3 days]
Phase 1 — Real stem separation (open_DAW)           [4 days]
Phase 2 — Vocal restoration chain (cross-repo)      [7 days]   ★ flagship
Phase 3 — Neutone plugin runtime (open_DAW)         [5 days]
Phase 4 — CLAP reference matching (mastering_tool)  [3 days]
Phase 5 — Master bus integration (cross-repo)       [6 days]
Phase 6 — Whisper-driven vocal QC (mastering_tool)  [3 days]
```

A "day" is roughly one focused work session, not 8 wall-clock hours. If anything blocks, **post the blocker as a GitHub issue on the relevant repo and stop**; do not silently invent workarounds.

---

## 3. Branch and PR strategy

Both repos: develop on `claude/wonderful-johnson-h6xj4d`. One PR per phase. PR description must include:

- Acceptance criteria checklist (copy from this doc)
- A/B audio artifacts: link or attach 3-track comparison
- Test results: `cargo test`, `pytest`, and any new scripts
- Risk notes
- Determinism check (re-run, MD5 the outputs, paste hashes)

Do not open a PR for the next phase until the previous one is merged or explicitly waived by the human.

---

## Phase 0 — Catalogue Hygiene (`mastering_tool`)

**Why:** the repo has 30 numbered `MASTERING_REPORT(N).md` and ~16 `master_pipeline_*.sh` variants. Adding new surface area on top of this is reckless.

### Deliverables

1. `mastering_tool/archive/` directory created. Move all `MASTERING_REPORT(*).md`, `final_loudness(*)`, `full_diagnostic(*)`, `premaster_diagnostic(*).{sh,txt}`, `stage_clip_limit(*).sh`, `spectral_analysis(*).sh`, `before_after(*).png`, `determinism_md5(*).txt`, `files*.zip` into `archive/` preserving filenames.
2. `mastering_tool/pipelines/` directory: one **canonical** per-track pipeline per song (drop the `_v3`, `(N)` suffixes). When two variants exist for the same song, pick the one referenced by the most recent `MASTERING_REPORT.md` in the root.
3. `mastering_tool/MASTERING_REPORT.md` (top level): consolidated report indexing all canonical pipelines and their target metrics. Generated from a small script (`tools/build_index.py`) — keep the script in the repo.
4. `mastering_tool/CATALOGUE.md` regenerated against the new layout.

### Do NOT

- Delete anything. Move to `archive/`. Disk is cheap; provenance is not.
- Change any DSP parameters. This phase is filesystem-only.

### Acceptance

- `git status` shows no `.wav` deletions.
- `bash pipelines/<any_canonical>.sh` runs end-to-end and produces bit-identical output to the previous canonical run (record MD5 before move, verify after).
- `MASTERING_REPORT.md` lists every track in `CATALOGUE.md`'s "Master 16-bit" section.

### Decision points for the human

- (D0.1) When two `_v3` and `(2)` variants disagree, which to canonicalize? Default rule: prefer the variant whose `final_loudness.txt` matches the project's `-10 LUFS / -1.0 dBTP` target. If neither does, flag and stop.

---

## Phase 1 — Real Stem Separation (`open_DAW`)

**Why:** `ai_modules/stem_extractor/__init__.py` declares a Demucs path but `separate()` returns stub paths. Every downstream phase depends on real stems.

### Tool choice

- **Primary:** Mel-Band RoFormer (vocals model: `KimberleyJSN/melbandroformer`, instrumental model: `pcunwa/Mel-Band-Roformer-Inst`). SOTA on SDX23/SDX24 leaderboards for vocal separation as of mid-2026.
- **Fallback:** Demucs v4 `htdemucs_ft` for 4-stem (drums/bass/vocals/other) when the input genre is poorly handled by RoFormer (mostly: orchestral, heavy classical — not our case).
- **Wrapper:** `python-audio-separator` (`pip install "audio-separator[gpu]>=0.21"`). Single API for both backends, handles model downloads, ONNX runtime, chunking.

### Deliverables

1. `open_DAW/ai_modules/stem_extractor/separator.py` — real implementation. Replaces the TODO in `__init__.py`. API contract unchanged: `separate(audio_path, stems=None, callback=None) -> Dict[str, Path]`.
2. `open_DAW/ai_modules/stem_extractor/models.py` — model registry. Each entry has `id`, `backend` (`roformer` | `demucs`), `hf_repo`, `target_stem`, `sdr_benchmark`.
3. `open_DAW/ai_modules/stem_extractor/requirements.txt` — pinned deps. Include `audio-separator[gpu]==0.21.x`, `torch>=2.3`, `onnxruntime-gpu`, `soundfile`, `numpy<2`.
4. `open_DAW/ai_modules/stem_extractor/cache.py` — content-addressed cache keyed on `(audio_sha256, model_id, version)`. Stored under `~/.opendaw/stem_cache/`.
5. `open_DAW/ai_modules/stem_extractor/tests/test_separator.py` — fixture: 30-second clip from `mastering_tool` catalogue. Asserts each stem file exists, has non-zero energy, and the vocal+instrumental sum reconstructs the original within ±0.5 dB RMS.
6. CLI wrapper: `open_DAW/ai_modules/stem_extractor/cli.py` — `python -m ai_modules.stem_extractor.cli separate <input.wav> --backend roformer --stem vocals --out <out.wav>`.

### Implementation notes

- Default backend = `roformer`, default target = `vocals`.
- Progress callback fires once per chunk during separation, not after each stem.
- If GPU unavailable, log a warning and fall back to CPU. Do not silently downgrade quality.
- Stems must be 32-bit float WAV at the source sample rate. No silent resampling.

### Acceptance

- `pytest open_DAW/ai_modules/stem_extractor/tests/` — green.
- On `MONSTAH_demo_1_gg.mp3` (already in `mastering_tool/source/`): vocal stem listened to in headphones — minimal instrumental bleed, no glaring artifacts.
- SDR (vs the original full mix as proxy, or `museval` if reference stems available) — vocal SDR > 8.5 dB on the test clip.
- Cache: second run on the same file returns in < 200 ms.

### Decision points

- (D1.1) GPU availability on the executor's machine? If none, increase phase budget — CPU separation of a 3-minute track is 8-15 minutes.
- (D1.2) Suno tracks are stereo-mixed, often with vocal-doubling and harmonies. If the chosen RoFormer model collapses harmonies, switch to `BS-RoFormer-1297` and re-baseline.

---

## Phase 2 — Vocal Restoration Chain (cross-repo) ★ FLAGSHIP

**Why:** the user's stated #1 pain point. Today's `vocal_prep.sh` runs on the full mix and is constrained by what won't hurt the instrumental. Stem-isolated processing lets us be aggressive on the voice and re-blend.

### The SUNO artifact catalogue (target list)

| Artifact | Symptom | Stage that fixes it |
|---|---|---|
| Metallic sibilance | Zinging 6-8 kHz on sustained S/T | dynamic de-esser + spectral repair |
| Plastic timbre | "Robotic", uncanny-valley, hollow | VoiceFixer / Apollo restoration |
| Codec smearing | HF wash, transient softening | Apollo (lossy-codec restoration) |
| Over-gated breaths | Missing inhales between phrases | expansion + room-tone bed |
| Flat micro-dynamics | Loss of natural vocal swell | transient designer + parallel comp |
| Reverb wash / room mush | Bedroom-recording smear | DeepFilterNet (reverb suppression) |
| Pitch artifacts on long notes | Subtle wobble or flatness | rubberband micro-pitch correction (only if flagged by QC) |

### Tool choice (open-source, MIT/Apache where possible)

- **`VoiceFixer`** — `pip install voicefixer`. MIT. Targets plastic/synthetic vocal quality directly. Mode 0 = clean, Mode 1 = noisy, Mode 2 = TTS-like (closest to SUNO).
- **`Apollo`** (Sony / JusperLee) — HuggingFace `JusperLee/Apollo`. Restores audio degraded by lossy codecs and generative pipelines. Best on the smearing/HF-wash class of artifacts.
- **`Resemble Enhance`** — `pip install resemble-enhance`. Two-stage denoise+enhance. Good complement when DeepFilterNet alone doesn't kill the room.
- **`DeepFilterNet3`** — `pip install deepfilternet`. Apache-2.0. Real-time noise/reverb suppression. Also has a Rust crate `deep_filter` — usable later in `daw-engine`.
- **`audiosr`** (Audio Super-Resolution) — `pip install audiosr`. Optional 48 kHz upsampling pass for bandlimited SUNO output.

### Architecture: where the chain lives

- **Restoration chain is owned by `mastering_tool`** (it's a mastering-side concern). New file:
  `mastering_tool/vocal_restore.sh` — orchestrator, calls Python helpers.
- **Stem separation is delegated to `open_DAW`** via subprocess to the CLI built in Phase 1:
  `python -m ai_modules.stem_extractor.cli separate ...`
  → `mastering_tool` requires `open_DAW` to be checked out as a sibling directory; auto-detected with `OPEN_DAW_PATH` env var (fallback: `../open_DAW`).
- **Python helpers** live in `mastering_tool/tools/vocal_restore/`:
  - `restore.py` — chains VoiceFixer → Apollo → DeepFilterNet. Toggleable per stage.
  - `remix.py` — re-mixes restored vocal back with original instrumental, with configurable gain match and crossover for breath-bed.
  - `requirements.txt` — pinned.

### The full chain

```
input.wav (stereo SUNO bounce)
  │
  ├─ [open_DAW CLI] separate → vocal.wav, instrumental.wav  (Mel-Band RoFormer)
  │
  ├─ vocal.wav:
  │     ├─ [DeepFilterNet3]  → de-room/de-noise           (toggle: VR_DEROOM=1)
  │     ├─ [VoiceFixer mode 2] → de-plastic                (toggle: VR_VOICEFIXER=1)
  │     ├─ [Apollo]           → de-codec / restore HF      (toggle: VR_APOLLO=1)
  │     ├─ [optional audiosr] → 48k SR                     (toggle: VR_AUDIOSR=0)
  │     └─ vocal_restored.wav
  │
  ├─ instrumental.wav: passthrough
  │
  ├─ [remix.py] vocal_restored + instrumental + breath_bed  → restored_full_mix.wav
  │
  └─ [existing vocal_prep.sh] restored_full_mix → vocal_prep.wav  (the polish stage)
       → handoff to master_pipeline*.sh
```

### Deliverables

1. `mastering_tool/vocal_restore.sh` — orchestrator. Same env-var conventions as `vocal_prep.sh`. Conservative defaults. Writes `VOCAL_RESTORE_REPORT.md` next to the output.
2. `mastering_tool/tools/vocal_restore/restore.py` — Python helper. Single `--stage` switch per restoration step. Idempotent. Streams progress to stderr.
3. `mastering_tool/tools/vocal_restore/remix.py` — re-mixer with `--gain-match {none,lufs,rms}` and `--breath-bed {none,roomtone_path}`.
4. `mastering_tool/tools/vocal_restore/requirements.txt` — pinned.
5. `mastering_tool/tools/vocal_restore/MODELS.md` — table of model IDs, licenses, sizes, expected GPU/CPU runtime per minute of audio.
6. Updated `mastering_tool/vocal_prep.sh` — no behavior change, but documents that it now operates on `restored_full_mix.wav` when fed from `vocal_restore.sh`.
7. Three A/B comparison artifacts in `mastering_tool/ab/phase2/`:
   - `<track>_baseline_vocalprep.wav` (current `vocal_prep.sh` only)
   - `<track>_restored_vocalprep.wav` (new chain → `vocal_prep.sh`)
   - `<track>_restore_report.md` (subjective notes + objective metrics: HF-cliff, crest, dF1 vocal formant clarity)
8. New top-level `mastering_tool/MASTERING_REPORT.md` section: "Vocal restoration chain — methodology and defaults".

### Reference tracks for A/B

Pick three from the existing SUNO-sourced catalogue spanning artifact profiles:
- `MONSTAH_demo_1_gg.mp3` (lossy, dark-top, squashed — codec smearing)
- `Sieh_zu_Ex_Hardcore_Pop_x_dr_Khans` (vocal-forward Hardcore Pop)
- `Phoneless_Hardcore_Pop` (dense mix, vocal sits low)

### Acceptance

- `bash vocal_restore.sh source/MONSTAH_demo_1_gg.mp3 ab/phase2/MONSTAH_restored.wav` runs to completion.
- Restored vocal-only stem played solo: vocoder-like "plastic" quality reduced subjectively by the human reviewer. The PR must include the human's listen-back notes.
- Objective: vocal LTAS slope from 2 kHz to 8 kHz becomes monotonically less harsh (delta ≥ 1.5 dB at 6.5 kHz on the bracket S/T regions).
- Determinism: same input + same env vars → identical SHA-256 on the restored vocal stem (after seeding RNGs in the Python helpers).
- Full pipeline `vocal_restore.sh → master_pipeline_<track>.sh` still hits the project's `-10 LUFS / -1.0 dBTP` master target.

### Decision points

- (D2.1) Which restoration model leads the chain on a given input? Default = VoiceFixer mode 2 → Apollo. The human can override per track via env var.
- (D2.2) Breath bed: synthesize from room-tone capture, or borrow from a non-SUNO commercial reference? Default = synthesize (pink + breath-shaped noise, -55 dBFS bed). Flag for review.
- (D2.3) Should the restored vocal be re-blended at the original vocal level or matched to the in-genre reference's vocal-to-mix ratio? Default = original level; the human approves a per-track override.

---

## Phase 3 — Neutone Plugin Runtime (`open_DAW`)

**Why:** the user explicitly asked about AI plugin creator tools. Neutone is the right answer; we don't need to build one. Adopting it makes `open_DAW` a host for any HuggingFace audio model.

### Tool choice

- **Neutone SDK** (Qosmo Inc.) — GitHub `QosmoInc/neutone_sdk`. Apache-2.0. Wraps PyTorch models as VST3/AU/LV2 plugins. Active development.
- **RAVE** (IRCAM) — GitHub `acids-ircam/RAVE`. Apache-2.0. Train timbre-transfer models on our mastered catalogue.
- **DDSP** (Magenta) — GitHub `magenta/ddsp`. Apache-2.0. Differentiable DSP for tone-shaping.

### Deliverables

1. `open_DAW/ui/src/Plugins/NeutoneHost.{cpp,h}` — JUCE plugin host wrapper that loads Neutone-format plugin files. Single-instance per track for now.
2. `open_DAW/ai_modules/neutone_bridge/` — new Python module:
   - `wrap_model.py` — wraps an arbitrary PyTorch checkpoint as a Neutone-compatible model.
   - `pretrained.py` — registry of curated public models (RAVE pretrained on speech, DDSP pretrained on violin, etc.).
   - `requirements.txt`.
3. `open_DAW/daw-engine/src/plugin_slot.rs` — Rust audio graph node representing a plugin insert. Currently FFI-only; behavior is gain passthrough until Phase 3 lands actual processing.
4. Three tests in `open_DAW/daw-engine/tests/plugin_slot_test.rs`: insert/remove, bypass toggle, dry/wet mix.
5. `open_DAW/docs/PLUGINS.md` — how to add a new Neutone plugin to the DAW, with a worked example using a public RAVE checkpoint.

### Out of scope (Phase 3)

- Training custom RAVE models on the user's catalogue. That's Phase 3.5, gated on Phase 3 success.
- Plugin parameter automation. Phase 3 ships static-parameter inserts.

### Acceptance

- `cargo test -p daw-engine plugin_slot` — green.
- Manual: load a pretrained RAVE timbre-transfer plugin in the JUCE UI, route a vocal stem through it, monitor output. Capture screenshot/audio in PR.
- Plugin bypass produces bit-identical output to direct routing.

### Decision points

- (D3.1) Plugin format priority: VST3, AU, LV2? Default = VST3 first (broadest DAW compatibility), LV2 second (matches the `Airwindows_clippers.lv2.tar.gz` workflow in `mastering_tool`).

---

## Phase 4 — CLAP Reference Auto-Matching (`mastering_tool`)

**Why:** `REFERENCE_LIBRARY.csv` (43 columns) is purely numeric. Picking the right reference for a new track is currently manual. CLAP embeddings turn it into a vector-search problem.

### Tool choice

- **LAION-CLAP** — `pip install laion-clap`. Open-source CLIP-for-audio. Pretrained model: `630k-audioset-best.pt`.

### Deliverables

1. `mastering_tool/tools/clap_match/` directory.
2. `mastering_tool/tools/clap_match/embed.py` — computes a CLAP embedding for a WAV file. Outputs to a sidecar `.npy` next to the audio.
3. `mastering_tool/tools/clap_match/index.py` — rebuilds `mastering_tool/reference_clap_index.npz` (matrix of embeddings + filename index) from the references in `REFERENCE_LIBRARY.csv`.
4. `mastering_tool/tools/clap_match/match.py` — given a new track, returns top-K nearest references by cosine similarity. CLI: `python -m tools.clap_match.match <new_track.wav> --k 5`.
5. `mastering_tool/tools/clap_match/requirements.txt`.
6. Update `reference_benchmark.sh` so that adding a new reference also computes its embedding and re-indexes.
7. Update `matchering_xcheck.py` to accept `--auto-reference` which uses CLAP to pick the closest reference instead of taking a manual path.

### Acceptance

- On three known SUNO-source tracks where the user has previously picked a reference manually, CLAP's top-3 must include the human's pick. Log the result in `tools/clap_match/A_B.md`.
- Indexing the full `REFERENCE_LIBRARY.csv` completes in < 2 minutes on CPU.

### Decision points

- (D4.1) Genre filter before CLAP, or pure semantic similarity? Default = pure CLAP, with a `--genre` optional pre-filter from `REFERENCE_LIBRARY.csv`.

---

## Phase 5 — Master Bus Integration (cross-repo)

**Why:** today the mastering chain is a post-bounce shell script. Bringing a non-trivial subset of it into `open_DAW`'s master bus lets us audition mastering choices during mixing. Faster iteration, fewer surprises.

### Approach

Do NOT port FFmpeg to Rust. The pipeline's calibration is the value, not the code. Instead, expose **two execution modes**:

- **Offline mode (existing):** `master_pipeline_*.sh` after bounce. Source of truth.
- **Live monitoring mode (new):** a Rust master-bus plugin (`master_bus_emulator`) implementing a **reduced fidelity** preview of the deterministic chain — HPF, parametric EQ, comp, soft-clip, look-ahead limiter. Parameter values are sourced from a JSON sidecar generated by the offline pipeline.

This gives the producer real-time "what will mastering do to this mix" preview without claiming bit-equivalence.

### Deliverables

1. `open_DAW/daw-engine/src/master_bus.rs` — master bus node: HPF, 4-band parametric EQ, single-band compressor, soft-clipper, look-ahead limiter. Each as a separate sub-node, bypassable.
2. `open_DAW/daw-engine/tests/master_bus_test.rs` — golden tests against numpy-generated reference signals (±0.01 dB tolerance).
3. `mastering_tool/tools/export_chain_to_json.py` — parses a `master_pipeline_*.sh` and emits a `chain.json` consumable by the master bus.
4. `open_DAW/ui/src/MasterBus/` — JUCE panel with bypass per stage, gain reduction meters, A/B toggle vs. raw output.
5. `open_DAW/docs/MASTER_BUS.md` — explicit statement that this is **preview, not delivery**. Final delivery still goes through `master_pipeline_*.sh` for determinism and dBTP guarantees.

### Acceptance

- `cargo test master_bus` — green.
- A 30-second sine sweep through `master_bus.rs` with a known `chain.json` matches the offline pipeline within ±0.5 dB at every 1/3-octave band.
- Manual: load a mix in `open_DAW`, toggle the master bus on/off, audit subjectively.

### Decision points

- (D5.1) Reduced-fidelity preview is acceptable, right? If the human wants bit-exact preview, scope balloons to porting FFmpeg filter behavior — flag and stop.

---

## Phase 6 — Whisper-Driven Vocal QC (`mastering_tool`)

**Why:** SUNO often mushes consonants. A transcription confidence score per word/phoneme is a cheap, diagnostic flag — "the word 'translate' in bar 14 has 31% confidence vs the catalogue average of 78%."

### Tool choice

- **`faster-whisper`** — `pip install faster-whisper`. CTranslate2-backed Whisper. Way faster than OpenAI's reference impl.
- Model: `large-v3`. Word-level timestamps required.

### Deliverables

1. `mastering_tool/tools/vocal_qc/transcribe.py` — runs faster-whisper on a vocal stem, emits per-word JSON with timestamps and confidence.
2. `mastering_tool/tools/vocal_qc/diagnose.py` — flags words below a confidence threshold (default 0.55), correlates with spectral data from `premaster_diagnostic.sh` to suggest cause (sibilance, mud, breath gate).
3. `mastering_tool/tools/vocal_qc/report.md.tmpl` — Markdown template.
4. CLI: `python -m tools.vocal_qc.diagnose <vocal_stem.wav> --lyric <lyric.txt>` (lyric optional; without it, compares to whisper's free-form transcript).
5. Three example reports in `tools/vocal_qc/examples/`.

### Acceptance

- Runs in under 1 minute on a 3-minute vocal stem (CPU acceptable; GPU preferred).
- On a track with a known mush issue (the human will provide one in D6.1), the flagged regions match the human's annotations within ±1 word.

### Decision points

- (D6.1) Which track is the "ground truth" mush-issue track for tuning? Human picks.

---

## 4. Cross-cutting concerns

### Determinism

Everything Python-side must:
- Seed `random`, `numpy.random`, `torch.manual_seed`, `torch.cuda.manual_seed_all`.
- Use `torch.use_deterministic_algorithms(True)` where supported.
- Record the determinism status in the per-stage report.

### Environment

- Python: 3.11. Locked via `pyproject.toml` or `requirements.txt` per phase.
- Rust: stable, current.
- CUDA: if available, use it; if not, run CPU and warn. Never silently swap models.
- GPU memory budget: assume 12 GB. If a phase needs more, flag and stop.

### Licensing

All chosen tools are MIT / Apache-2.0 / BSD. No GPL surprises. Re-verify when pinning versions; if a dependency upgrades to GPL, escalate to the human before pinning.

### Data hygiene

- Never commit `.wav` masters or sources to git.
- Phase 0's `archive/` includes existing artifacts; add to `.gitignore` going forward.
- Use git-lfs for any binary that must be tracked (icon, screenshots — already in repo).

### Telemetry / no phone-home

No HuggingFace `inference_endpoints` calls at runtime. Models are downloaded once, cached, then used offline. The pipeline must work air-gapped after initial setup.

---

## 5. Risks and known unknowns

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Mel-Band RoFormer collapses harmonies | medium | Phase 2 quality | fallback to `BS-RoFormer-1297`, then Demucs `htdemucs_ft` |
| VoiceFixer + Apollo stacked introduce artifacts | medium | Phase 2 quality | per-stage toggle; default to single-stage if A/B fails |
| Neutone plugin format churn | low | Phase 3 maintenance | pin Neutone SDK version; vendor the runtime if upstream breaks |
| CLAP confuses genre on Hardcore-Pop | medium | Phase 4 accuracy | hybrid: CLAP + numeric prefilter from `REFERENCE_LIBRARY.csv` |
| Master bus preview drifts from offline pipeline | high | Phase 5 trust | explicit "preview, not delivery" docs; CI test against goldens |
| Whisper-large-v3 too slow on CPU | low | Phase 6 latency | swap to `medium.en` if user is anglophone-only |

---

## 6. Done criteria (whole plan)

The unified toolkit is "done" for v1 when:

1. From a SUNO MP3 dropped into `mastering_tool/source/`, one command produces:
   - A restored vocal-isolated chain output
   - A reference auto-matched via CLAP
   - A vocal QC report (Whisper-flagged words)
   - A finished master at `-10 LUFS / -1.0 dBTP`
2. From `open_DAW`, the producer can:
   - Drop a SUNO stem on a track
   - Hear the master bus preview
   - Insert at least one Neutone plugin
3. All phase tests are green in CI (set up in Phase 0 as a side concern).
4. The catalogue is hygienic — no `(N)` suffixed duplicates outside `archive/`.

---

## 7. Out of scope (explicitly)

- Training new neural models from scratch. We adopt pretrained checkpoints only.
- Mobile / web UI. Desktop-first.
- Real-time co-editing / cloud sync.
- Genre detection ML (CLAP is good enough as a stand-in).
- DRM, watermarking, distribution.

---

## 8. Communication with the human

- One PR per phase. Description references this document's phase number.
- Blocker → GitHub issue → stop. Do not invent a workaround unless the workaround is reversible and disclosed in the PR description.
- A/B audio artifacts are non-optional for Phase 2, 3, 5. Without them the PR will be sent back.
- Decision points (D-numbered above) are escalated as GitHub issues with the `decision` label. Default behavior is documented; the human can override per case.

---

## 9. Companion document in `open_DAW`

This file is mirrored to `open_DAW/UNIFIED_EXECUTION_PLAN.md`. Both repos hold the same plan so the executor sees it regardless of which repo it starts a session in. Update both when the plan changes.

---

*End of plan.*
