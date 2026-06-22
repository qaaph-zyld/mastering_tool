# Execution Plan — Addendum & Reality Correction (2026-06-22)

**Supersedes:** the "Phases 3–6 Ready" handoff (`2026-06-22_190500_music_ai_toolshop_phases_3_6.md`) where it conflicts with the verified git state below.
**Verified against:** GitHub remotes `qaaph-zyld/mastering_tool` and `qaaph-zyld/open_DAW`, branch `claude/wonderful-johnson-h6xj4d`, on 2026-06-22.

---

## 1. Verified git reality (this is the source of truth, not the handoff)

### `open_DAW` — branch `claude/wonderful-johnson-h6xj4d`

| Commit | Phase | State |
|---|---|---|
| `2199eca` | Phase 1 — real stem separation (RoFormer/Demucs, cache, CLI, tests) | committed |
| `e98188b` | Phase 3 — Neutone plugin host (`plugin_slot.rs`, `neutone_bridge/`, JUCE wrapper, docs) | committed |
| `022beea` | Phase 5 — master bus preview (`master_bus.rs` +406 lines, tests, JUCE panel, docs) | committed |
| `918ddfa` | fix — repair `Optional` import in `cli.py` | committed (HEAD) |

**Phases 1, 3, and 5 are already implemented and pushed on `open_DAW`.** Quality is *unverified* — see §3.

### `mastering_tool` — branch `claude/wonderful-johnson-h6xj4d`

| Commit | Phase | State |
|---|---|---|
| `276bd5d` | UNIFIED_EXECUTION_PLAN.md | committed (HEAD) |

**Nothing else.** The handoff's claimed Phase 0 (`2c420ec`) and Phase 2 (`b04d0b9`) commits **do not exist on the remote** — not on the feature branch, not on `main`, and the objects are not fetchable. No `archive/`, no `pipelines/`, no `vocal_restore.sh`, no `tools/vocal_restore/` anywhere on the remote.

---

## 2. Two corrections to the handoff

1. **The handoff says Phase 0 + Phase 2 are done and committed on `mastering_tool`. They are NOT on GitHub.** This is the flagship SUNO vocal-restoration work plus catalogue hygiene. It exists only in the Windsurf local working copy — if at all — and is **unbacked-up and at risk.** Recovering/pushing it is priority #1.

2. **The handoff says Phase 3 + Phase 5 are "Not started." They are already committed on `open_DAW`** (`e98188b`, `022beea`). Earlier guidance to "defer Phases 3 and 5" is therefore moot — the code exists. The task there is **verification and review**, not deferral or building.

---

## 3. Corrected priority order

### P1 — Recover & push the `mastering_tool` flagship work (URGENT)
From the Windsurf `mastering_tool` clone:
- Confirm the Phase 0 + Phase 2 commits actually exist locally (`git log`, look for the `archive/`, `pipelines/`, `vocal_restore.sh`, `tools/vocal_restore/` artifacts).
- If they exist: `git push -u origin claude/wonderful-johnson-h6xj4d`. Then re-verify on GitHub.
- If they do NOT exist locally: the work was lost and must be redone per the original plan's Phase 0 + Phase 2 sections.
- Likely root cause: the push silently went to the wrong remote, or was never run (same class of confusion as the earlier "wrong repo" episode). Verify `git remote -v` points at `github.com/qaaph-zyld/mastering_tool`.

### P2 — Verify the existing `open_DAW` Phases 1/3/5 (don't rebuild)
- `cargo test` in `daw-engine/` — must be green (Phase 1 separator, `plugin_slot`, `master_bus` tests).
- `pytest` for `stem_extractor` and `neutone_bridge`.
- Note: Phase 3 needed a follow-up import fix (`918ddfa`), so it was committed without being run cleanly — treat all three as unverified until tests pass in a clean checkout.
- Confirm `daw-engine/target/` is fully gitignored (build artifacts were committed then untracked in `e98188b`; verify none remain tracked).

### P3 — Build the genuinely-remaining phases (CPU-friendly, on `mastering_tool`)
- **Phase 4 — CLAP reference auto-matching.**
- **Phase 6 — Whisper-driven vocal QC.**
- These remain unstarted in both handoff and reality. Decisions below stand.

---

## 4. Settled decisions (carry forward)

**Hardware budget (hard constraint):** target PCs have 8 GB and 16 GB RAM, modest GPUs — assume no usable CUDA. Default to CPU. Reject any model that won't run comfortably under ~4 GB RAM on the 8 GB box. Lean on existing open-source; code only when nothing fits.

- **D3.1 (Neutone format):** effectively pre-answered by `e98188b` (generic loader + `neutone_bridge`). Review the committed approach rather than re-decide.
- **D4.1 (CLAP model):** `laion-clap`, checkpoint `630k-audioset-best.pt`, CPU inference. NOT `microsoft/clap`.
- **D5.1 (master bus):** the committed `master_bus.rs` (`022beea`) already chose a native-Rust preview. Verify it against the offline shell pipeline; treat as **preview, not delivery**. Do not expand scope without a need.
- **D6.1 (Whisper):** `faster-whisper`, `large-v3` int8 (`compute_type="int8"`); fall back to `medium.en` int8 if RAM-tight (detect & log). NOT `openai-whisper`, NOT `insanely-fast-whisper`.

---

## 5. Standing discipline

One PR per phase. Push to `claude/wonderful-johnson-h6xj4d` on both repos; do not open PRs unless the human asks. A/B audio artifacts where applicable. Seed all RNGs for determinism. Stop-and-ask on: dependency install failures, OOM on the 8 GB box, `REFERENCE_LIBRARY.csv` having < 5 entries, or anything that would break determinism.

---

*This addendum is mirrored to both repos. The body of `UNIFIED_EXECUTION_PLAN.md` remains the detailed reference; where this addendum and the plan's phase ordering disagree, this addendum wins.*
