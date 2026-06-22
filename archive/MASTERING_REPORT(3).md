# Mastering Report — `All_the_Things_She_Said_Hardcore_Pop_2`

**Date:** 2026-06-04
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `All_the_Things_She_Said_Hardcore_Pop_2.wav` (16-bit PCM, **48 kHz**, stereo, 4:07.92)
**Family:** Hardcore Pop sub-family. **Direct sibling:** `All_the_Things_She_Said_Hardcore_Pop_1` (mastered 2026-06-01) — Part 1 of the same song and the primary tuning reference. Other siblings: `Little_Planet_Hardcore_Pop_1`, `How_It_Ends_Up_Hardcore_Pop_2`, `Chips_in_the_Oven_Hardcore_Pop_1`.
**Target:** −10.0 LUFS integrated / ≤ −1.0 dBTP true peak (house standard, **all three deliverables**)
**Toolchain:** FFmpeg 6.1.1 + soxr (precision 28). No proprietary plugins.

---

## Pre-Master Diagnosis

Measured with the v2 diagnostic (the v1 grep-based phase block was restored to the working aphasemeter-metadata aggregator at the start of the session, per standing framework practice).

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **−13.2 LUFS** | Quiet; needs ~+3.2 dB to target. 0.8 dB louder than Part 1 (−14.0) |
| Loudness range (LRA) | **7.6 LU** | **2nd most dynamic source in the family** (after `NE_SALJI` 8.1; ahead of Part 1's 6.6) |
| True peak | **−0.7 dBTP** | Hot but compliant; no inter-sample clipping (Part 1 was −1.2) |
| Sample peak | −0.73 dBFS | Hot, headroom-safe |
| Crest factor | ~14.4 dB | Dynamic (peak −0.73 / RMS −15.11) — ties Part 1 |
| DC offset | −0.000163 | Small but non-negligible → corrected with `dcshift=+0.000163` |
| Stereo correlation | mean **0.550** / **min −0.498** / max 0.999 (11,622 frames) | Min negative → **fails mono-safety check** → widening skipped |

### Spectral balance (octave bands, RMS dB)

| Band | Part 2 (this) | Part 1 (sibling) | Read |
|---|---|---|---|
| 20–60 Hz subbass | −22.6 | −20.8 | Modest (Part 1 was subbass-dominant; this isn't) |
| 60–120 Hz bass | **−20.6** | −21.2 | **Strongest band — fundamental / club anchor** |
| 120–250 Hz lowmid | −21.9 | −23.5 | Clean — sits below bass, no mud build-up |
| 250–500 Hz mid | −23.9 | −25.3 | |
| 500 Hz–1 kHz | −24.4 | −27.3 | |
| 1–2 kHz upmid | −26.5 | −30.1 | |
| 2–4 kHz presence | **−30.4** | −32.1 | Recessed, but *less* recessed than Part 1 |
| 4–8 kHz brilliance | **−33.5** | −32.1 | Recessed — *more* than Part 1 |
| 8–16 kHz air | **−35.2** | −31.3 | **Rolled off, BELOW brilliance — darkest air in the family** |
| 16 kHz+ ultra | −45.3 | −42.0 | Steep roll-off |

**Key reads and the decisions they drove:**

1. **Quiet + the most dynamic top of the recent family.** Loudness is the headline job; a large, *empirically calibrated* limiter pre-gain is required. With LRA 7.6, glue stays moderate (not crushing) to preserve the lively macro-dynamics.
2. **Dark *and rolled-off* top — the key difference from Part 1.** Part 1's air band was *alive* (−31.3, sitting **above** brilliance), so it received only a measured air touch. Part 2's top descends monotonically — presence −30.4 → brilliance −33.5 → air −35.2 — the bass→air slope is ~14.6 dB vs Part 1's ~10.5 dB. This is a genuinely closed top and warrants the family's full "open the dark top" treatment, weighted toward the more-recessed brilliance/air rather than presence.
3. **Bass-dominant, clean low end.** Bass (−20.6) is the single strongest band; low-mid (−21.9) sits cleanly below it (no mud), and subbass (−22.6) is modest. Therefore **no bass boost** (it would risk boom under the big make-up gain) and only a gentle low-mid clarity cut as insurance.
4. **Min phase correlation −0.498.** Negative → mono fold-down risk → **stereo widening skipped** per standing family policy. The stage is retained in the architecture (`m=1.0`); only headroom prep is applied.
5. **DC offset −0.000163** is larger than the family's "skip" threshold → DC removal re-enabled with the inverse shift.

---

## Mastering Chain

Five-stage architecture, all processing at 32-bit float internally, **native 48 kHz preserved end-to-end** (oversampling happens only inside the limiter). Conditional stages (DC removal, stereo widening) are **retained but gated** per their criteria — never deleted.

### Stage A — Prep
- `volume=-6dB` — headroom for the EQ boosts (post-prep peak ≈ −6.7 dBFS)
- `dcshift=0.000163` — cancels the −0.000163 DC offset
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz

### Stage B — Parametric EQ (dark + rolled-off top profile)

| Filter | Freq | Gain | Q | Purpose | vs Part 1 |
|---|---|---|---|---|---|
| Bell | 220 Hz | **−0.8 dB** | 1.1 | Low-mid clarity insurance under big gain | lighter (Part 1: −1.0) |
| Bell | 3.2 kHz | **+1.2 dB** | 1.2 | Presence lift (recessed leads/vocals) | gentler (Part 1: +1.5 — less recessed here) |
| Bell | 6 kHz | **+1.5 dB** | 1.0 | Brilliance / hardcore bite (more recessed) | stronger (Part 1: +1.0) |
| Bell | 11 kHz | **+2.5 dB** | 0.7 | **Full broad air lift** (top genuinely rolls off) | stronger (Part 1: +1.5 — its air was alive) |

No low-end boost: the bass is already the strongest band. The EQ inverts Part 1's HF weighting — Part 1 favored presence/brilliance with a measured air touch; Part 2 favors brilliance/air with a full air shelf, because that's where *this* source rolls off.

### Stage C — Bus compression (glue)
`acompressor=threshold=-18dB:ratio=1.8:attack=25:release=200:makeup=1.5:knee=4`

Moderate 1.8:1 glue with a slow 25 ms attack to preserve transient punch on a dynamic source (LRA 7.6, crest ~14.4). Matches the direct sibling's glue for family consistency; pulled source LRA 7.6 → 6.2 before the limiter.

### Stage D — Stereo stage (widening skipped)
`extrastereo=m=1.00,volume=-3dB`

Min phase correlation −0.498 fails mono safety → **no widening** (`m=1.0`). Stage retained per framework; only −3 dB headroom prep applied. Verified post-master: phase character preserved (mean 0.556 / min −0.464 / max 0.999 — essentially unchanged from source, no widening artifacts).

### Stage E — 4× oversampled true-peak limiting
Two parallel limiter passes from the same Stage-D source:
- **E1 (lossless):** `volume=+10.5dB` → `aresample=192000:soxr:precision=28` → `alimiter=limit=0.85:attack=2:release=80:level=disabled` → `aresample=48000:soxr:precision=28`. Brickwall at −1.4 dBFS in the 192 kHz oversampled domain catches inter-sample reconstruction overshoot a sample-peak limiter would miss; guarantees ≤ −1.0 dBTP after downsampling.
- **E2 (MP3 source):** identical chain at ceiling **0.82** — a dedicated lower-ceiling source so the lossy encode stays true-peak-safe.

#### Pre-gain calibration (empirical bracketing — the shortcut under-shoots dynamic sources)
End of Stage D measured **−19.6 LUFS**. Shortcut formula predicted +9.6 dB; the dynamic source under-shot by 0.9 dB, so the value was bracketed:

| Pre-gain | Integrated | LRA | True peak |
|---|---|---|---|
| **+10.5 dB** | **−10.0 LUFS** | 5.0 LU | −1.4 dBTP |
| +11.5 dB | −9.5 LUFS | 4.5 LU | −1.4 dBTP |
| +12.0 dB | −9.2 LUFS | 4.2 LU | −1.4 dBTP |
| +12.5 dB | −9.0 LUFS | 3.9 LU | −1.4 dBTP |

Selected **+10.5 dB → −10.0 LUFS** (exact house target), the limiter holding true peak constant at −1.4 dBTP.

#### MP3 ceiling calibration
Part 1 reconstructed hot and needed ceiling 0.77; Part 2 reconstructs gently:

| MP3 ceiling | MP3 integrated | MP3 true peak | Verdict |
|---|---|---|---|
| **0.82** | −10.1 LUFS | **−1.4 dBTP** | ✓ PASS (matches WAV loudness) |
| 0.80 | −10.2 LUFS | −1.7 dBTP | pass, over-quiet |
| 0.78 | −10.3 LUFS | −1.9 dBTP | pass, over-quiet |
| 0.77 | −10.4 LUFS | −2.0 dBTP | pass, over-quiet |

Selected **0.82** — confirms the framework lesson that `libmp3lame` overshoot is content-dependent and must be calibrated per track, never assumed from a sibling.

---

## Final Master Metrics

| Metric | Target | 32f WAV | 16-bit WAV | MP3 320k |
|---|---|---|---|---|
| Integrated loudness | −10.0 LUFS | **−10.0** | **−10.0** | **−10.1** |
| True peak | ≤ −1.0 dBTP | **−1.4** | **−1.4** | **−1.4** |
| Loudness range | < 8 LU | 5.0 | 5.0 | 4.8 |

**All three deliverables independently pass the house standard** (−10 LUFS, ≤ −1.0 dBTP). Unusually for the family, the MP3 meets the true-peak target with the same −1.4 dBTP margin as the WAVs.

### Spectral changes (master − source, dB)

Net integrated gain was +3.2 dB; the "relative" column subtracts it, isolating **shape** change.

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20–60 Hz subbass | +2.67 | **−0.53** (limiter taming dominant lows) |
| 60–120 Hz bass | +2.46 | **−0.74** |
| 120–250 Hz lowmid | +2.36 | **−0.84** (−0.8 @ 220 cut visible) |
| 250–500 Hz mid | +3.14 | −0.06 (neutral) |
| 500 Hz–1 kHz | +3.65 | +0.45 |
| 1–2 kHz upmid | +3.82 | +0.62 |
| **2–4 kHz presence** | +4.45 | **+1.25** ✓ |
| **4–8 kHz brilliance** | +5.10 | **+1.90** ✓ |
| **8–16 kHz air** | +5.26 | **+2.06** ✓ |
| **16 kHz+ ultra** | +4.71 | **+1.51** ✓ |

Confirms intent: the dark, rolled-off top is opened with a brilliance/air-weighted lift (+1.9 / +2.1, stronger than presence's +1.25 — the inverse of Part 1), the midrange held neutral, and the dominant low end gently tamed by the limiter so it no longer overwhelms while keeping its intended weight. The track moves from bass-heavy/closed to open and bright without losing body.

---

## Family comparison

| Track | Source LUFS | LRA | Min phase | Air band | Widening | Air lift | MP3 ceiling |
|---|---|---|---|---|---|---|---|
| **ATTSS Part 2 (this)** | −13.2 | **7.6** | −0.498 | **−35.2** | skipped | **+2.5** | 0.82 |
| ATTSS Part 1 | −14.0 | 6.6 | −0.90 | −31.3 (alive) | skipped | +1.5 | 0.77 |
| How_It_Ends_Up | −13.0 | 6.3 | −0.52 | −30.8 | conservative | +2.5 | — |
| Little_Planet | −13.2 | 4.7 | −0.743 | −34.1 | skipped | ~+1.5 | — |
| 10_outta_10 | −12.5 | 4.1 | −0.603 | −33.4 | skipped | +1.7 | — |
| NE_SALJI | — | 8.1 | — | — | — | — | — |

Part 2 is the family's 2nd most dynamic source and has its darkest air band — hence the largest air lift (+2.5, tied with the dark-rolled-off members) and the moderate, transient-preserving glue.

---

## Streaming platform compliance

| Platform | Target LUFS | Master −10.0 | Result |
|---|---|---|---|
| Spotify / YouTube / Tidal | −14 | −10.0 | Normalized down ~4 dB |
| Apple Music | −16 | −10.0 | Normalized down ~6 dB |
| Amazon Music | −14 | −10.0 | Normalized down ~4 dB |
| Club / DJ use | −8 to −10 | −10.0 | Direct play, ideal |

True peak at −1.4 dBTP across all deliverables leaves headroom so no clipping occurs even after lossy re-encoding (AAC/Opus) by streaming services.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `..._MASTER_32f.wav` | 32-bit float, 48 kHz | Archival / future re-encoding |
| `..._MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | Distribution (canonical master) |
| `..._MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming / DJ / preview |

**Determinism:** a second independent pipeline run reproduced the 16-bit master **byte-identical** (MD5 `432075e2890614f3506a8c9d60f95a24`) — the chain is fully deterministic and auditable.

---

## Project directory tree

```
All_the_Things_She_Said_Hardcore_Pop_2/
├── MASTERING_REPORT.md
├── source/
│   └── All_the_Things_She_Said_Hardcore_Pop_2.wav        (read-only copy of upload)
├── analysis/
│   └── premaster_diagnostic.txt
├── intermediate/                                          (all 32f stages retained for audit)
│   ├── 01_prep.wav
│   ├── 02_eq.wav
│   ├── 03_comp.wav
│   ├── 04_stereo.wav
│   ├── 05_limited.wav            (E1 — lossless master source)
│   └── 05_limited_mp3src.wav     (E2 — MP3 true-peak-safe source)
├── master/
│   ├── All_the_Things_She_Said_Hardcore_Pop_2_MASTER_32f.wav
│   ├── All_the_Things_She_Said_Hardcore_Pop_2_MASTER_16.wav
│   └── All_the_Things_She_Said_Hardcore_Pop_2_MASTER.mp3
├── verification/
│   ├── final_loudness.txt
│   ├── post_spectral.txt
│   ├── determinism_md5.txt
│   └── directory_tree.txt
└── scripts/
    ├── master_pipeline_ATTSS2.sh
    └── premaster_diagnostic.sh   (v2-corrected)
```

---

## Framework notes carried forward

1. **MP3 overshoot is per-track.** Direct siblings Part 1 (ceiling 0.77) and Part 2 (ceiling 0.82) bracket a 5-point spread on the same song — always calibrate the E2 ceiling by sweep, never inherit it.
2. **Shortcut pre-gain under-shoots dynamic sources** — confirmed again here (predicted +9.6, needed +10.5 for −10.0 LUFS at LRA 7.6). Bracketing remains mandatory.
3. **"Dark" ≠ "rolled-off."** Part 1 and Part 2 are both dark, but Part 1's air was alive (lift restrained) while Part 2's air rolls off below brilliance (full air lift). Read the *slope and the brilliance↔air relationship*, not just the bass→air gap, before choosing the air-lift amount.
