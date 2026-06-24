# Phase 9 — Calibration & Validation Hardening

**Created:** 2026-06-24
**Predecessor:** Phase 8 (validated, `207e345` on `mastering_tool`, `5fffdcd` on `open_DAW`)
**Status:** READY FOR EXECUTION — do this before any new feature work.

---

## Why this phase exists

Phase 8 proved the chain runs end-to-end on real audio with real models. It did **not** prove the chain is useful. Three substantive gaps from the validation:

1. **Vocal QC flagged ALL 3 tracks** (10–19 artifacts each). No negative control — we don't know if the flagger is informative or just always-on. A binary classifier that's always positive carries no information.
2. **CLAP top matches all map to our own finished masters** (similarity 0.77–0.87). This is because `REFERENCE_LIBRARY.csv` contains only our work. The tool is currently a **house-style matcher**, not a commercial-reference matcher. Either is valid; we have to pick which we're shipping.
3. **No human listen-back acceptance yet.** `_chain_rendered.wav` exists for every track but is unrated. "Pipeline runs" ≠ "pipeline works."

Also: `open_DAW` has CI; `mastering_tool` does not. Asymmetric discipline.

---

## Tasks (do in order)

### 9.1 — Vocal QC: negative + positive controls

**Goal:** know whether the QC flagger is informative.

Run `tools/vocal_qc/vocal_qc.py` on three classes of input:
- **Negative control A:** a known-clean professional vocal stem (any commercial vocal you trust — separated via the same RoFormer path).
- **Negative control B:** one of `master/*_MASTER_32f.wav` from your catalogue (your finished, ratified work).
- **Positive control:** a raw clean vocal recording, captured pre-Suno (you against a mic, no processing).

Compute the flag-rate distribution per class. Acceptance: **clean controls (A, B) false-positive rate < 20%.** If they flag at the same rate as Suno output, raise thresholds in `vocal_qc.py` until they don't — and document the rationale inline.

**Deliverable:** `docs/PHASE9_QC_CALIBRATION.md` with the per-class flag rates, the chosen thresholds, and comments in `vocal_qc.py` explaining the calibration.

### 9.2 — A/B listen-back

**Goal:** ratify the chain audibly, not just programmatically.

For each of the 3 Phase 8 tracks, build a side-by-side comparison artifact. Minimum viable: an HTML page (or a single Markdown table with absolute file paths) that lets the producer A/B:
- `<basename>_restored_full_mix.wav` (post-restoration, pre-chain)
- `<basename>_chain_rendered.wav` (after the Vocal Doctor's recommended chain)

Producer scores each on a 1–5 scale across: **naturalness, sibilance control, fullness, "feels human."**

Acceptance: **`chain_rendered >= restored` on the mean of those four metrics across the 3 tracks.** If the chain doesn't improve on restoration, the Vocal Doctor's recommendations are wrong — debug rules in `tools/vocal_doctor/recommend.py` before building on top.

**Deliverable:** `docs/PHASE9_LISTEN.md` with the scoring table. Coder queues it up; the producer rates.

### 9.3 — CLAP positioning decision

**Goal:** stop conflating two different products.

Pick one of two paths and implement it:

- **Path (i) — House Style Matcher.** Either rename `tools/clap_matcher/` to `tools/house_style_matcher/` or add `--mode=house_style` and document it as the primary use. CLAP queries your own catalogue; the value is consistency with your past work.
- **Path (ii) — Commercial Reference Matcher.** Populate `REFERENCE_LIBRARY.csv` with **≥ 10 commercial in-genre tracks** (Hardcore-Pop / trap / hip-hop). Tag every row `source = ours | commercial`. Add `--source {ours,commercial,both}` filter to the CLAP CLI. Default for new tracks: `commercial`.

**Default if the producer doesn't decide within 24h:** Path (ii). The original brainstorm goal was "learn from the best in industry" — that's commercial references, not our own work. House style matching is a fallback, not the headline use case.

**Deliverable:** decision logged in `docs/PHASE9_CLAP_POSITIONING.md` + the code change.

### 9.4 — Symmetric CI for `mastering_tool`

**Goal:** match the discipline `open_DAW` already has.

Add `mastering_tool/.github/workflows/ci.yml`:
- Ubuntu runner (the tools are pure-Python; no need for Windows here)
- Python 3.13
- pip cache via `actions/cache@v4` keyed on `tools/*/requirements.txt` hashes
- Runs `pytest tools/`
- Heavy ML deps (torch, voicefixer, audio-separator, faster-whisper, laion-clap, pedalboard) are **not** installed in CI — keep the existing mock/skip pattern for tests that need them. CI verifies the rule-based logic and packaging, not the model paths.
- CI badge in `README.md` matching the `open_DAW` style.

**Deliverable:** CI green on the feature branch.

### 9.5 — Determinism check

**Goal:** know what's reproducible.

Re-run `phase8_validate.py` twice on the same 3 tracks with the same env. Diff every artifact (audio: SHA-256; JSON: byte-compare). Report what's reproducible and what isn't. Likely culprits: VoiceFixer STFT padding, CLAP embedding floating-point drift, faster-whisper sampling.

Seed where you can. Document the irreducible noise floor where you can't.

**Deliverable:** new "Determinism" section appended to `docs/PHASE8_VALIDATION.md` with the diff results and seeding strategy.

---

## Acceptance for the whole phase

- 9.1 calibration plot + thresholds committed; clean-vocal false-positive rate < 20%.
- 9.2 listen-back scores collected; chain ratified or rules debugged.
- 9.3 CLAP product framing decided and implemented.
- 9.4 `mastering_tool` CI green on the feature branch with badge.
- 9.5 determinism noted; seeds added where possible.

Push everything to `claude/wonderful-johnson-h6xj4d`. **No PRs** unless the producer asks.

---

## Hard stop-and-ask triggers

- Listen-back scoring requires the producer — queue and wait, don't proceed.
- If clean controls flag at the same rate as Suno output even with maximum-conservative thresholds, the QC heuristics need redesign, not retuning — stop and report.
- If the CLAP positioning decision isn't made within 24h, default to Path (ii) and log the auto-decision.

---

## What comes after Phase 9

Only after 9 passes, in priority order:
1. **House Style Dashboard (Phase 7d)** — streamlit + UMAP over CLAP embeddings; the data is now real, the visualization is the unlock.
2. **Stem-isolated reverse engineering + `dasp` inverse DSP (Phase 7b)** — `docs/RE_AUDIT.md` already scoped it.
3. **Layering Assistant** — the new product surface from the earlier roadmap; still unbuilt.
4. **Vocal Doctor v2 (learned)** — only if v1's rules plateau after 9.1 calibration.

---

*End of Phase 9 plan.*
