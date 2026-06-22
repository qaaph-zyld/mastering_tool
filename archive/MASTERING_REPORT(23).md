# Mastering Report — `Keine_Zeit_zu_Verlieren`

**Date:** 2026-06-05
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Keine_Zeit_zu_Verlieren_-_Hardcore_Pop_x_Mixall.wav` (16-bit PCM, 48 kHz, stereo, 2:10)
**House standard:** −10.0 LUFS integrated / ≤ −1.0 dBTP true peak (all deliverables)
**Sibling template:** `All_the_Things_She_Said_Hardcore_Pop_2` ("ATTSS2", 48k-native, 2026-06-04)

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **−13.8 LUFS** | Quiet → large pre-gain required (0.6 dB below ATTSS2) |
| Loudness range (LRA) | **3.1 LU** | ⚠ **Tightest source in the family** (ATTSS2 7.6, NE_SALJI 8.1) |
| True peak / sample peak | **−2.0 dBFS** | Clean — 1.3 dB more headroom than ATTSS2 |
| Crest factor | ~13.5 dB | Transients survive despite squashed macro-dynamics |
| DC offset | **+0.000313** | Non-negligible → corrected (opposite sign & larger than ATTSS2) |
| Phase correlation | mean 0.788 / **min −0.723** / max 0.998 | ⚠ Fails mono safety → **widening skipped** |
| Mid / Side RMS | −15.6 / −32.6 dB | Side 17 dB down → largely centered content |

> Diagnostic run with the restored **v2 `premaster_diagnostic.sh`** (phase block aggregates per-frame `lavfi.aphasemeter.phase` to mean/min/max via awk; the snapshot's v1 grep block returns empty). 6092 phase frames captured.

### Spectral balance (octave bands, RMS dB)

| Band | RMS | Read |
|---|---|---|
| 20–60 Hz subbass | −21.9 | Solid |
| 60–120 Hz bass | **−20.5** | Strongest — fundamental |
| 120–250 Hz lowmid | −22.0 | Clean (below bass) |
| 250–500 Hz mid | −25.6 | |
| 500 Hz–1 kHz | −27.7 | |
| 1–2 kHz upmid | −30.3 | |
| 2–4 kHz presence | −30.5 | Recessed |
| 4–8 kHz brilliance | −30.7 | Recessed but **healthier than ATTSS2 (−33.5)** |
| 8–16 kHz air | −32.9 | Dark, but **not dead** (ATTSS2 was −35.2) |
| 16 kHz+ ultra | −43.8 | Roll-off |

**Profile:** Classic family bass-dominant / dark-top — but *evenly* dark rather than steeply rolled-off. The whole upper range sits ~30–33 dB, so the top needs lifting toward presence/air, with **less brilliance rescue** than ATTSS2 required.

---

## Parameter Tuning — deltas from the ATTSS2 sibling template

| Decision | This track | ATTSS2 | Reasoning |
|---|---|---|---|
| Glue ratio | **1.4:1** | 1.8:1 | LRA 3.1 is the tightest in the family; heavier glue would over-squash already-flat dynamics |
| Glue attack | 30 ms | 25 ms | Slower → protect the surviving transients (crest ~13.5) |
| Brilliance lift | **+1.0 @ 6k** | +1.5 @ 6k | Brilliance only −30.7 here (healthier) — needs less rescue |
| Air lift | **+2.0 @ 11k** | +2.5 @ 11k | Air −32.9 dark but not dead — slightly less broad lift |
| DC correction | dcshift **−0.000313** | +0.000163 | Larger, opposite-sign measured offset |
| Widening | **skipped (m=1.0)** | skipped (m=1.0) | min corr −0.723 (even more phase-risky than ATTSS2's −0.498) |
| Pre-gain | **+9.4 dB** | +10.5 dB | Sweep-calibrated to −10.0 LUFS (see below) |

---

## Mastering Chain

All processing performed at 32-bit float internally, 48 kHz preserved end-to-end. Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-6dB` — creates headroom
- `dcshift=-0.000313` — cancels measured +0.000313 source DC offset
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz

### Stage B — Parametric EQ (dark + evenly-dark top, bass-dominant)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 220 Hz | **−0.8 dB** | 1.1 | Low-mid clarity insurance under big make-up gain |
| Bell | 3.2 kHz | +1.2 dB | 1.2 | Presence lift (recessed −30.5) |
| Bell | 6 kHz | +1.0 dB | 1.0 | Brilliance touch (only −30.7 — lighter than ATTSS2) |
| Bell | 11 kHz | +2.0 dB | 0.7 | Broad air lift (air −32.9, dark but not dead) |

No low-end boost: bass −20.5 is already the strongest band; boosting would risk boom under +9.4 dB of make-up.

### Stage C — Bus compression (gentle glue)
`acompressor=threshold=-18dB:ratio=1.4:attack=30:release=200:makeup=1.5:knee=4`

A light 1.4:1 ratio at 30 ms attack — the lightest glue in the family, chosen because LRA 3.1 leaves little macro-dynamic range to compress. Adds cohesion without pumping.

### Stage D — Stereo stage (widening skipped) + headroom prep
- `extrastereo=m=1.00` — **widening skipped**; min phase correlation −0.723 fails mono safety. Stage retained in architecture per framework policy.
- `volume=-3dB` — headroom prep for the limiter.

### Stage E — 4× oversampled true-peak limiting (split lossless / MP3)
Two parallel limiter passes feed the deliverables:

**E1 (lossless WAV):** `volume=+9.4dB` → `aresample=192000:soxr:precision=28` → `alimiter=limit=0.85:attack=2:release=80` → `aresample=48000:soxr:precision=28`

**E2 (MP3 source):** identical chain but `alimiter=limit=0.82` — a dedicated lower ceiling feeding only the lossy encode, because libmp3lame's filterbank reconstruction generates true-peak overshoot independent of the WAV ceiling.

---

## Gain Calibration Sweep (empirical, not formula)

End-of-Stage-D loudness = **−19.4 LUFS**. The "target − stage-D" shortcut predicted **+9.4 dB**.

**Pre-gain sweep @ ceiling 0.85:**

| Pre-gain | Integrated | True peak |
|---|---|---|
| **+9.4 dB** | **−10.0 LUFS** ✓ | −1.4 dBTP |
| +10.0 dB | −9.6 LUFS | −1.4 dBTP |
| +10.5 dB | −9.2 LUFS | −1.4 dBTP |
| +11.0 dB | −8.9 LUFS | −1.4 dBTP |

Here the shortcut **matched** the empirical result — unlike dynamic sources, this one is so tight (LRA 2.4 post-glue) that the limiter does almost no gain reduction, so loudness tracks pre-gain linearly. **Locked +9.4 dB.**

**MP3 ceiling sweep @ +9.4 dB:**

| MP3 ceiling | MP3 integrated | MP3 true peak |
|---|---|---|
| 0.85 | −10.0 LUFS | −1.2 dBTP (already passes) |
| **0.82** | **−10.1 LUFS** | **−1.4 dBTP** |
| 0.80 | −10.1 LUFS | −1.7 dBTP |
| 0.78 | −10.2 LUFS | −2.0 dBTP |

This source reconstructs gently in libmp3lame (0.85 already passed at −1.2). **Locked 0.82** for clean margin and to match the WAV true peak.

---

## Final Master Metrics

| Metric | Target | 32f WAV | 16-bit WAV | MP3 | Status |
|---|---|---|---|---|---|
| Integrated | −10.0 LUFS | −10.0 | −10.0 | −10.1 | ✓ |
| True peak | ≤ −1.0 dBTP | −1.4 | −1.4 | −1.5 | ✓ |
| Loudness range | — | 2.4 | 2.4 | 2.4 | ✓ |

### Spectral changes (master − source, dB)

| Band | Source | Master | Δ |
|---|---|---|---|
| 20–60 Hz subbass | −21.9 | −19.0 | +2.9 |
| 60–120 Hz bass | −20.5 | −17.5 | +3.0 |
| 120–250 Hz lowmid | −22.0 | −19.0 | +3.0 |
| 250–500 Hz mid | −25.6 | −22.5 | +3.1 |
| 500 Hz–1 kHz | −27.7 | −24.3 | +3.4 |
| 1–2 kHz upmid | −30.3 | −26.3 | +4.0 |
| 2–4 kHz presence | −30.5 | −25.6 | **+4.9** |
| 4–8 kHz brilliance | −30.7 | −25.2 | **+5.5** |
| 8–16 kHz air | −32.9 | −27.2 | **+5.7** |
| 16 kHz+ ultra | −43.8 | −38.6 | +5.2 |

The low end rises ~+3 dB (the loudness normalization), while presence/brilliance/air rise ~+5 to +5.7 dB. Net effect: a **relative brightening of ~+2.5 dB** across the top, with the −0.8 @ 220 Hz cut keeping the low-mid from ballooning under the big make-up gain. Bass weight preserved; top opened up.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `Keine_Zeit_zu_Verlieren_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `Keine_Zeit_zu_Verlieren_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | Distribution |
| `Keine_Zeit_zu_Verlieren_MASTER.mp3` | 320 kbps CBR (`-compression_level 0`), joint stereo | Streaming/preview |

MP3 verified as true CBR (320000 bit/s exact, not VBR).

---

## Determinism Verification

Two independent full-pipeline runs, MD5-compared — **all three deliverables bit-identical**:

```
fc5ea63f62b5fdfa23e8de9f664ab154  Keine_Zeit_zu_Verlieren_MASTER_32f.wav
3f90f43aafee48eb3aded70b090698c6  Keine_Zeit_zu_Verlieren_MASTER_16.wav
1fe3440019db9be6223b82d466c90c25  Keine_Zeit_zu_Verlieren_MASTER.mp3
```

---

## Streaming Platform Compliance

| Platform | Target LUFS | Master @ −10.0 | Result |
|---|---|---|---|
| Spotify | −14 | −10.0 | Turned down ~4.0 dB |
| Apple Music | −16 | −10.0 | Turned down ~6.0 dB |
| YouTube | −14 | −10.0 | Turned down ~4.0 dB |
| Tidal | −14 | −10.0 | Turned down ~4.0 dB |
| Club / DJ use | −8 to −10 | −10.0 | Direct play, ideal |

With true peak at −1.4 dBTP (−1.5 for MP3), no clipping occurs even after lossy re-encoding (AAC/Opus) by streaming services.

---

## Project Directory Structure

```
Keine_Zeit_zu_Verlieren/
├── source/         Keine_Zeit_zu_Verlieren.wav
├── analysis/       premaster_diagnostic.txt, master_bands.txt
├── intermediate/   01_prep → 05_limited (+ 05_limited_mp3src), all 32-bit float
├── master/         3 deliverables (32f / 16-bit / MP3)
├── verification/   determinism_md5.txt, final_loudness.txt
└── scripts/        master_pipeline_KZV.sh (this track),
                    master_pipeline_REFERENCE.sh (ATTSS2 sibling),
                    premaster_diagnostic.sh (v2, restored)
```

## Reusable script

```bash
bash scripts/master_pipeline_KZV.sh <source.wav> <output_name> <project_dir>
```

---

## Session notes for the framework

- **v2 diagnostic restored again** at session start (snapshot still ships broken v1). Making v2 canonical in the snapshot would eliminate this recurring step.
- This source is the new **low-water mark for dynamics** in the family (LRA 3.1) — documents the gentle-glue end of the compression tier (1.4:1).
- Confirms the calibration principle's *boundary*: the "target − stage-D" shortcut is accurate precisely when the source is already flat (minimal limiter reduction); it undershoots only on dynamic sources.
- Widening skipped for the 15th consecutive family track — the negative-min-correlation mono-safety policy continues to hold across the whole Hardcore Pop family.
