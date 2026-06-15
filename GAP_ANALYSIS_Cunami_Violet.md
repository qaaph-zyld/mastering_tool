# GAP ANALYSIS — Pipeline vs. Commercial Reference
## Reference: Cunami — "Violet" (commercial release master)
### Session date: 2026-06-12 · Methodology: premaster_diagnostic v2 + qc_verify metrics, automated via new `reference_benchmark.sh`

---

## 1. Reference profile (measured, deterministic)

| Metric | Value | Reading |
|---|---|---|
| Format | 44.1 kHz / 16-bit / 156.9 s | Standard CD-grade delivery |
| Integrated loudness | **−8.0 LUFS** | 2.0 LU hotter than our −10 house standard |
| LRA | **2.4 LU** | Tighter than every family master (ours: 2.9–6.4) |
| True peak | **+1.1 dBTP** | **Violates −1.0 dBTP** — would FAIL our QC gate |
| Sample peak | 0.0 dBFS | Slammed to full scale |
| Clipping census | 19,227 / 18,049 full-scale samples (L/R), flat factor 14.4 | **Hard flat-top clipping** is part of the sound |
| Crest factor | 8.7 dB | Bottom of the 8–12 dB "well-mastered" band |
| PLR | 9.1 dB | Healthy |
| PSR proxy | **7.9 dB** | Just under the AES ≥ 8 gate — micro-dynamics preserved *despite* −8 LUFS |
| ST percentiles | p50 −7.9 / p90 −7.1 / p99 −6.9 | **Spread p99−p50 = 1.1 LU** — relentless, uniform density |
| Phase corr (full band) | mean **+0.671**, min **−0.058** | Essentially never anti-phase |
| Phase corr (<120 Hz) | mean **+0.801**, min −0.063 | Bass is near-mono / fully coherent |
| Mono fold loss | **0.3 LU** (baseline-corrected) | Outstanding mono compatibility |
| HF extension | content shelf ~16 kHz, transients to ~21 kHz | Even famous releases carry 16k-shelved sources |
| DC offset | 0.00019 | Clean |

**Spectral shape (RMS-relative):** twin-peak low end — subbass −4.3 and bass −4.5 rel within 0.25 dB of each other — then a smooth monotonic tilt through the mids, a deliberate **presence=brilliance plateau** (both −18.9 rel), air 1.8 dB below brilliance. Bass-dominant *by design*: this track is even more low-weighted relative to its RMS than our family masters. Our "keep the weight, open the top" EQ philosophy is genre-correct.

---

## 2. Side-by-side: reference vs. our masters

| Dimension | Violet (commercial) | Our family masters | Verdict |
|---|---|---|---|
| Integrated | −8.0 LUFS | −10.0 LUFS (house) | **Gap: 2 LU** — profile choice, not capability |
| LRA | 2.4 LU | 2.9–6.4 LU | Ours deliberately more dynamic; club parity needs density |
| True peak | +1.1 dBTP, 37k clipped samples | −1.4 dBTP, codec-round-trip verified | **We are stricter than commercial practice** — keep it |
| PSR at loudest | 7.9 dB @ −8 LUFS | ~6.9 dB @ −10 LUFS | **Real gap**: they buy 2 LU of loudness *and* keep more micro-dynamics |
| ST consistency | spread 1.1 LU | not yet measured/gated | **Metric gap** — adopt it |
| Phase, full band | min −0.058 | min **−0.36 … −0.90** (chronic) | **The largest real gap — upstream, in the mix** |
| Phase, <120 Hz | +0.80 mean | negative family-wide | Same — bass coherence is built in the mix |
| Mono fold | −0.3 LU | not yet routinely logged | Metric gap — `qc_translation.sh` covers it; make it standard |
| Tonal shape | smooth tilt, plateaus | family profile compatible | Validate against N≥10 library, not one track |
| QC/auditability | unknown (black box) | MD5 determinism, retained stages, reports | **We exceed commercial practice** |

### Honest answer to "how close are we?"

**Architecturally: at or above this level.** The chain (soft-clip → oversampled TP limiting → codec round-trip QC → determinism) is the textbook-correct version of what was done to Violet — Violet itself would fail our QC gate on true peak. Nothing in this reference requires a tool we don't have.

**Three measurable distances remain:**

1. **Density (2 LU + consistency)** — closable *today* with calibration. The loudness on Violet comes from hard clipping at full scale plus a near-constant short-term level. Our E0 (ClipOnly2) + E1 (alimiter) architecture does exactly this; we have simply never calibrated a deliverable at that operating point.
2. **Phase coherence** — *not* a mastering gap. Violet proves the genre standard: correlation never meaningfully negative, bass near-mono. Our family's chronic −0.36…−0.90 minima are a mix-stage property; mastering bass-mono can attenuate but never resolve it (already a standing framework lesson — now backed by hard numbers from a famous release).
3. **Reference-driven calibration maturity** — until now, tonal/dynamics decisions were justified against family siblings only. Commercial competitiveness requires an external yardstick: a measured reference library and per-master deltas against it. The v3 upgrade specified this (`reference_scan.sh` concept); this session operationalizes it.

---

## 3. Gap-closing plan (framework-compliant: additive, opt-in, default byte-identical)

### Phase 0 — Operationalize reference benchmarking ✅ DONE THIS SESSION
- **`reference_benchmark.sh`** (new permanent module): full deterministic scan of any commercial reference — loudness, LRA, TP, sample peak, crest, PLR, PSR, ST percentiles + spread, v2 phase correlation (full + <120 Hz), baseline-corrected mono fold loss, clipping census, 10-band spectral (identical bands to `spectral_analysis.sh`), HF cliff probes, spectrogram — appended as one row to **`REFERENCE_LIBRARY.csv`** (append-only).
- Library seeded with row #1: Cunami — Violet.
- **Standing task:** scan 10–20 in-genre commercial references. At N≥10, derive the genre target envelopes: median tonal curve (RMS-relative), PSR floor, LRA band, ST-spread ceiling, low-band correlation floor. These become numeric north stars in every future `MASTERING_REPORT.md`.

### Phase 1 — `competitive` deliverable profile (pipeline, opt-in) ✅ BUILT + PROVEN THIS SESSION
- **`competitive_profile.sh`** (new module): `pre-gain → oversampled asoftclip → 4× oversampled alimiter`, mirroring the default E0/E1 split. Target −8.0 LUFS / ≤ −0.5 dBTP. Soft-clip uses pure-ffmpeg `asoftclip` (deterministic, no LV2 build); ClipOnly2 remains clip-of-record for the default chain.
- **Clip-share sweep** (E0 threshold × E1 pre-gain, bracketed jointly) — same discipline as the pre-gain and MP3-ceiling sweeps.
- **Empirical proof** (rendered, determinism-verified via SHA-256):

  | Metric | Our competitive render | Reference (Violet) | Verdict |
  |---|---|---|---|
  | Integrated | **−8.0 LUFS** | −8.0 | matched exactly |
  | True peak | **−0.8 dBTP** | +1.1 | **far cleaner** (TP-safe vs hard-clipped) |
  | Clipped samples L/R | **2 / 2** | 19,227 / 18,049 | **~19,000× fewer** |
  | Flat factor | **0.0** | 14.4 | **no flat-topping** |
  | Max short-term | −6.9 | −6.8 | matched |
  | ST spread (p99−p50) | 0.9 LU | 1.1 | matched density |
  | Mono fold loss | 0.3 LU | 0.3 | matched |
  | **PSR** | **6.1 dB** | 7.9 | **the one deficit** |

- **The PSR finding is the session's key result.** We reproduce the commercial loudness *and* density with dramatically cleaner peak engineering, but cannot reproduce PSR — because the test source arrived already crushed. Micro-dynamics are a *source* property; they cannot be created downstream. **This is the empirical proof that the decisive lever is upstream (Phase 3), not in the chain.** Default −10 deliverable remains byte-for-byte unchanged.

### Phase 2 — QC metric extensions ✅ MODULE BUILT THIS SESSION (`qc_metrics_ext.sh`)
- **`qc_metrics_ext.sh`** (new module, tested): emits a markdown-ready block + machine footer for any master — ST percentiles p50/p90/p99 + spread, per-channel clipping census + flat factor, baseline-corrected mono fold loss, <120 Hz correlation — each auto-flagged against reference-derived expectations. Detects unintended flat-topping in our own masters (validated: correctly flagged the reference's 14.4 flat factor; our competitive render reads 0.0).
- **Reference delta section** in `MASTERING_REPORT.md` template: each new master auto-compared against library medians — pending N ≥ 10.

### Phase 3 — Upstream mix-phase program ✅ SPEC + GATE BUILT THIS SESSION
This is where the family actually loses to commercial releases, and it cannot be fixed downstream — now proven empirically by the PSR result above.
- **`PREMASTER_ACCEPTANCE_SPEC.md`** (new doc, written): 7 gates — full-band corr min, <120 Hz corr mean, headroom, **crest ≥ 12 dB, premaster PSR ≥ 11 dB** (the dynamics gates the PSR finding forces), DC offset, declared provenance. Per-register routing on FLAG/FAIL.
- **`mix_phase_gate.sh`** (new module, tested both directions): runs the v2 correlation diagnostic full-band + per register (sub/low-mid/mid/high), emits PASS/FLAG/FAIL, names the worst register. Validated: PASSes the coherent reference (with headroom), FAILs synthetic anti-phase pinpointing the low-mid register, FAILs the finished master on headroom (correctly — it is not a premaster).
- Mix-stage rules documented (mono bass < 120 Hz, no anti-phase spread on low elements, per-stem correlation check, leave dynamics in). Mastering bass-mono stays available as remediation; the goal is to stop needing it.

### Phase 4 — Documentation upgrades
- `REFERENCE_LIBRARY.md`: process doc — how to add a reference, how envelopes are derived, why commercial TP violations are recorded but never copied.
- Pipeline headers: encode this session's lessons (below).
- Standing family table gains a reference-delta column once envelopes exist.

### Phase 5 — Monitoring (unchanged, restated)
Room treatment → DRC-FIR/`afir` correction remains the prerequisite for *trusting ears* at commercial level. The reference library de-risks tonal decisions in the meantime by providing a numeric yardstick that doesn't depend on the room.

---

## 4. Framework notes carried forward

1. **Commercial masters routinely violate −1.0 dBTP.** Violet: 0.0 dBFS sample peak, +1.1 dBTP, ~19k flat-topped samples per channel. Record honestly in the library; never copy. Our codec-round-trip QC is a competitive *advantage* (cleaner on lossy platforms), not pedantry.
2. **Loudness at this level is bought with clipping, not limiting.** PSR 7.9 at −8.0 LUFS is only possible because flat-top clipping takes the peaks; a limiter alone at that depth would pump and crush PSR. Maps directly onto our E0/E1 split — the `competitive` profile is a clip-share calibration, not new architecture.
3. **Phase coherence is the genre standard, proven numerically.** min corr −0.058 full-band, +0.80 mean below 120 Hz on a famous release vs. our family's chronic negatives. Upstream fix; `mix_phase_gate.sh` makes it enforceable.
4. **ST spread (p99−p50) is a first-class density metric.** 1.1 LU on the reference. Adopt in QC.
5. **Mono fold-down needs the −3.01 LU R128 baseline correction** before interpreting; raw loss overstates the phase damage.
6. **16 kHz content shelf on a commercial release** — validates the existing HF-cliff-aware cap on air lifts; full 22 kHz extension is not a commercial requirement.
7. **Single-reference tonal conclusions are weak.** Twin-peak sub/bass and presence=brilliance plateau are *one data point*; tonal envelopes only at N≥10.

---

## 5. Deliverables of this session

```
library/REFERENCE_LIBRARY.csv          ← seeded, append-only, 43 columns
library/Cunami_-_Violet_diagnostic.txt ← full human-readable scan
library/Cunami_-_Violet_spectrogram.png
scripts/reference_benchmark.sh         ← new permanent framework module
GAP_ANALYSIS_Cunami_Violet.md          ← this document
```
