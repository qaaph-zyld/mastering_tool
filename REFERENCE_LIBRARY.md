# REFERENCE LIBRARY
## How the commercial-reference benchmark system works
### v1.0 — 2026-06-12

The reference library is the project's **external numeric yardstick**. Until now,
every tonal and dynamics decision was justified against family siblings only —
an internally consistent but self-referential loop. A measured library of
commercial in-genre releases breaks the loop: it tells us where the family sits
against the actual market, independent of our own monitoring room.

---

## What it is

- **`reference_benchmark.sh`** — deterministic scanner. Given a commercial WAV,
  it measures the full metric set (loudness, LRA, true peak, sample peak, crest,
  PLR, PSR, short-term percentiles + spread, full-band and <120 Hz correlation
  via the v2 per-frame method, baseline-corrected mono fold-down, clipping
  census, 10-band octave RMS on the *same* bands as `spectral_analysis.sh`, HF
  cliff probes, spectrogram) and appends one row to the library CSV.
- **`REFERENCE_LIBRARY.csv`** — append-only, 43 columns, one row per reference.
- **`<name>_diagnostic.txt`** + **`<name>_spectrogram.png`** per reference.

The scan methodology is byte-for-byte the same as `premaster_diagnostic.sh` v2
and `qc_verify.sh`, so reference numbers and our own master numbers are directly
comparable — no apples-to-oranges.

---

## How to add a reference

```bash
bash reference_benchmark.sh "path/to/Commercial Track.wav" library/
```

Choose references that are: (a) in genre (Hardcore-Pop / trap / hip-hop),
(b) widely regarded as well-produced, (c) lossless or highest-available quality.
Note lossy provenance in the row if unavoidable — it inflates HF-cliff and
true-peak readings.

---

## Deriving the genre target envelopes (at N ≥ 10)

A single reference is one data point — its twin-peak sub/bass and
presence=brilliance plateau are **not** a target until corroborated. Once the
library holds ≥ 10 references, compute per-column:

| Envelope | From columns | Becomes |
|---|---|---|
| Tonal curve | `b20_60 … b16k_up` (RMS-relative) | median ± IQR target curve, per band |
| PSR floor | `psr_db` | 10th-percentile = minimum micro-dynamics bar |
| LRA band | `lra_lu` | inter-quartile range = acceptable dynamics window |
| ST-spread ceiling | `st_spread` | 90th-percentile = max acceptable density looseness |
| Low-band corr floor | `lowband_corr_mean` | 10th-percentile = bass-coherence bar |
| Loudness operating point | `integrated_lufs` | median = competitive-profile target |

These envelopes feed two places:
1. **`competitive_profile.sh`** target (currently hard-coded −8.0 from this one
   reference; replace with the library median).
2. **`MASTERING_REPORT.md`** — a new *reference-delta* section per master: each
   band's distance from the median curve, PSR vs floor, LRA vs band, etc.

---

## Honesty rules

1. **Record commercial true-peak violations; never copy them.** Violet sits at
   +1.1 dBTP with ~37k full-scale samples. The library logs this faithfully. Our
   masters stay true-peak-safe (≤ −0.5 competitive, ≤ −1.0 house) — cleaner on
   every lossy platform. The library is a map of the market, not a list of
   instructions.
2. **Loudness is bought with clipping, not limiting.** PSR 7.9 at −8.0 LUFS is
   only possible because flat-top clipping takes the peaks. We reproduce the
   loudness with a soft-clip/limiter split that leaves zero flat-tops — better
   engineering — but we cannot reproduce the *PSR* unless the source arrives
   dynamic (see PREMASTER_ACCEPTANCE_SPEC.md).
3. **Tonal conclusions require N ≥ 10.** No EQ move is justified "because the
   reference does it" until the envelope is statistical.

---

## Current contents

| # | Name | I (LUFS) | LRA | TP | PSR | <120 corr | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Cunami — Violet | −8.0 | 2.4 | +1.1 | 7.9 | +0.80 | Seed reference; heavy clip, TP-hot, bass near-mono |

*Add rows as references are scanned. Derive envelopes at N ≥ 10.*
