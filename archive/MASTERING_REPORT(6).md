# Mastering Report — `Chips_in_the_Oven_Hardcore_Pop_1`

**Date:** 2026-05-31
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Chips_in_the_Oven_Hardcore_Pop_1.mp3` → decoded to 32-bit float WAV, 48 kHz, stereo, 2:53
**House standard:** −10.0 LUFS integrated / ≤ −1.0 dBTP true peak
**Family position:** "Hardcore Pop" sibling of `Little_Planet_Hardcore_Pop_1` and `How It Ends Up Hardcore Pop 2`. Profile is the darkest-top, lowest-LRA member measured to date — nearest dynamic sibling is `Natti — Ohne Signal` (also dark, quiet, narrow, 48 kHz), whose pipeline served as the structural reference before per-source re-tuning.

---

## Pre-Master Diagnosis

Source was a lossy MP3 (~187 kbps VBR, 48 kHz). Decoded losslessly to 32-bit float WAV for processing; all measurement and processing performed at native 48 kHz (no rate conversion until the limiter's internal oversampling).

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **−13.4 LUFS** | Quiet for the family; needs ~+3.4 dB to target |
| Loudness range (LRA) | 3.9 LU | Already heavily limited / low dynamics |
| True peak | **−2.1 dBTP** | Clean — no inter-sample clipping (unusual; most siblings arrive hot) |
| Sample peak | −2.13 dBFS | Headroom present |
| Crest factor | ~13.2 dB (peak−RMS) | Moderate; consistent with a pre-limited source |
| DC offset | +0.000031 | Negligible (≈ −90 dB) → DC correction bypassed |
| Stereo correlation | mean **+0.68** / **min −0.91** / max +1.00 | ⚠ Strong out-of-phase moments → **widening must be skipped** |

### Spectral balance (octave bands, RMS dB)

| Band | RMS | Read |
|---|---|---|
| 20–60 Hz subbass | −21.6 | Solid |
| 60–120 Hz bass | **−20.4** | Strongest — fundamental / club anchor |
| 120–250 Hz lowmid | −22.7 | **Below** bass → no mud build-up |
| 250–500 Hz mid | −26.1 | |
| 500 Hz–1 kHz | −26.5 | |
| 1–2 kHz upmid | −27.5 | |
| 2–4 kHz presence | −29.0 | Recessed |
| 4–8 kHz brilliance | −30.6 | Dark |
| 8–16 kHz air | −32.8 | Thin top |
| 16 kHz+ ultra | −42.5 | Roll-off (encoder taper, content present to ~17 kHz) |

**Key issues:** Strongly **dark-top** — bass-to-air gap ≈ 12.4 dB (vs ~9 dB on the `zeldi` sibling). Low end is bass-dominant but **clean** (low-mids sit below bass, so no 200 Hz mud cut needed). True peak is already safe. Phase content has deep out-of-phase passages (min −0.91), so the track is treated as a mono-compatibility risk and not widened.

**HF cutoff check:** content tapers gradually rather than via a hard encoder lowpass — real energy persists to ~17 kHz (13–15 kHz at −39 dB, 15–16 kHz at −42 dB, 16–17 kHz at −44 dB). The air lift is therefore placed as a broad shelf at 10.5 kHz to raise genuine content, not fabricate dead ultra-high.

---

## Mastering Chain

All processing at 32-bit float internally. Five-stage architecture preserved in full; conditional stages (DC removal, stereo widening) are **retained but bypassed** on this source per their gating criteria.

### Stage A — Prep
- `volume=-6dB` — creates headroom
- DC correction **bypassed** — offset +3.1e-5 is negligible; the stage remains in the chain architecture, applied conditionally
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz

### Stage B — Parametric EQ (dark-top profile, re-derived for this source)
| Filter | Freq | Gain | Q / width | Purpose |
|---|---|---|---|---|
| Bell | 220 Hz | −0.8 dB | 1.1 | Light low-mid tightening (no mud cut needed — low-mids already clean) |
| Bell | 90 Hz | +0.8 dB | 1.3 | Reinforce fundamental / club weight |
| Bell | 3 kHz | +1.5 dB | 1.2 | Restore presence (source recessed at −29 dB) |
| Bell | 6 kHz | +1.8 dB | 1.0 | Brilliance lift (source dark at −30.6 dB) |
| High shelf | 10.5 kHz | +2.5 dB | 0.7 | Broad air lift — raises real content (≤ ~17 kHz), not dead ultra-high |

Rationale vs the family: most siblings get a 200 Hz mud cut and a single broad 12 kHz air bell. This source needed the **opposite low-end treatment** (only a token 220 Hz nudge, since low-mids are clean) and a **more aggressive, segmented top** (separate presence, brilliance, and air moves) because it is the darkest member measured.

### Stage C — Bus compression (glue)
`acompressor=threshold=-18dB:ratio=1.5:attack=30:release=200:makeup=1.0:knee=4`

Source LRA is already 3.9, so a deliberately light 1.5:1 glue pass. A 30 ms attack (slower than the `natti` template's 25 ms) preserves club transients given the genre.

### Stage D — Stereo stage (**widening skipped**)
- `extrastereo` **bypassed** — minimum phase correlation −0.91 fails the mono-safety check (widening is skipped whenever min correlation approaches or crosses zero)
- `volume=-3dB` — headroom prep into the limiter

The widening stage remains in the pipeline architecture; only the `extrastereo` operator is removed for this source. Several family members (`Natti — Ohne Signal`, others) have failed the same check.

### Stage E — 4× oversampled true-peak limiting (192 kHz)
Two parallel limiter passes from the same Stage-D signal:

- **E1 (lossless masters):** `volume=+12.5dB` → `aresample=192000:soxr:precision=28` → `alimiter=limit=0.85:attack=2:release=80:level=disabled` → `aresample=48000:soxr:precision=28`
- **E2 (MP3 source):** identical, but `alimiter=limit=0.82` — a lower ceiling, because `libmp3lame` generates reconstruction peaks independent of the WAV ceiling. The 320 kbps MP3 is encoded from this true-peak-safe source so it stays ≤ −1.0 dBTP after lossy encoding.

Limiting performed 4× oversampled (48 → 192 kHz) so the brickwall catches inter-sample reconstruction overshoot, then downsampled back to 48 kHz with the SoX high-precision resampler.

---

## Limiter Pre-Gain Calibration

Stage-D measured **−22.4 LUFS**. The shortcut formula (target − stage-D = −10 − (−22.4)) gives **+12.4 dB** as a starting point. Bracketed across three values through the full oversampled limiter and selected the most transient-preserving compliant result:

| Pre-gain | Integrated | True peak | LRA | Verdict |
|---|---|---|---|---|
| +11.5 dB | −10.9 LUFS | −1.4 dBFS | 3.5 LU | Under target |
| **+12.5 dB** | **−10.1 LUFS** | **−1.4 dBFS** | **3.4 LU** | ✓ **Selected** — on target, most dynamics retained |
| +13.5 dB | −9.4 LUFS | −1.4 dBFS | 3.1 LU | Over target, more limiting |

Locked at **+12.5 dB**: hits target while preserving the widest LRA among on-target options.

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | −10.0 LUFS | **−10.1 LUFS** | ✓ |
| True peak (32f / 16 / MP3) | ≤ −1.0 dBTP | **−1.4 / −1.4 / −1.4 dBTP** | ✓ |
| Loudness range | — | 3.4 LU (MP3 3.3) | ✓ controlled |

MP3 true peak independently re-verified by decoding the 320 kbps file and re-measuring: **−1.4 dBTP** — the Stage E2 lower ceiling held.

### Spectral changes (master − source, RMS dB)

| Band | Δ | Read |
|---|---|---|
| 20–60 Hz subbass | +2.6 | rises with overall level |
| 60–120 Hz bass | +2.8 | overall level |
| 120–250 Hz lowmid | +2.7 | overall level — **no mud added** |
| 250–500 Hz mid | +2.6 | overall level |
| 500 Hz–1 kHz | +2.9 | overall level |
| 1–2 kHz upmid | +3.4 | slight presence rise |
| **2–4 kHz presence** | **+4.3** | **net brightening** |
| **4–8 kHz brilliance** | **+4.9** | **net brightening** |
| **8–16 kHz air** | **+4.9** | **net brightening** |
| 16 kHz+ ultra | +5.2 | shelf tail |

Against the ~+2.7 dB overall level rise, the EQ contributed roughly +1.6 to +2.3 dB of genuine top-end lift. Bass-to-air gap narrowed from **12.4 dB → 10.3 dB**: the dark top is opened up while the low end keeps its weight and the low-mids stay clean.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `Chips_in_the_Oven_Hardcore_Pop_1_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `Chips_in_the_Oven_Hardcore_Pop_1_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | Distribution |
| `Chips_in_the_Oven_Hardcore_Pop_1_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview |

All three measure −10.1 LUFS / −1.4 dBTP (LRA 3.4, MP3 3.3).

---

## Determinism Verification

The 32-bit float master was reproduced in an independent second run and compared by MD5:

```
run1 = a7ea525132ecbca1ec5141ea72120207
run2 = a7ea525132ecbca1ec5141ea72120207
match = YES  → pipeline is deterministic
```

---

## Reusable Script

`scripts/master_pipeline.sh` reproduces the entire chain (pre-gain defaults to the calibrated +12.5 dB; override as the 4th arg):

```bash
bash scripts/master_pipeline.sh <source.wav> <output_name> <project_dir> [PREGAIN_DB]
```

`scripts/premaster_diagnostic.sh` is the **v2** diagnostic with the corrected phase-correlation block (per-frame `lavfi.aphasemeter.phase` aggregation — the v1 grep approach produced empty output).

---

## Streaming Platform Compliance

| Platform | Target LUFS | Master @ −10.1 | Result |
|---|---|---|---|
| Spotify | −14 | −10.1 | Turned down ~3.9 dB to −14 |
| Apple Music | −16 | −10.1 | Turned down ~5.9 dB |
| YouTube | −14 | −10.1 | Turned down ~3.9 dB |
| Tidal | −14 | −10.1 | Turned down ~3.9 dB |
| Club/DJ use | −8 to −10 | −10.1 | Direct play, ideal |

True peak at −1.4 dBTP leaves margin so no clipping occurs even after lossy re-encoding (AAC/Opus) by streaming services.

---

## Project Directory Tree

```
Chips_in_the_Oven_Hardcore_Pop_1_project/
├── MASTERING_REPORT.md
├── source/
│   ├── Chips_in_the_Oven_Hardcore_Pop_1.mp3      (original)
│   └── Chips_in_the_Oven_Hardcore_Pop_1.wav      (32f working copy)
├── analysis/
│   └── premaster_diagnostic.txt
├── intermediate/
│   ├── 01_prep.wav
│   ├── 02_eq.wav
│   ├── 03_comp.wav
│   ├── 04_stereo.wav
│   ├── 05_limited.wav                            (E1 → WAV masters)
│   └── 05_limited_mp3src.wav                     (E2 → MP3 source)
├── master/
│   ├── Chips_in_the_Oven_Hardcore_Pop_1_MASTER_32f.wav
│   ├── Chips_in_the_Oven_Hardcore_Pop_1_MASTER_16.wav
│   └── Chips_in_the_Oven_Hardcore_Pop_1_MASTER.mp3
├── verification/
│   └── verification_summary.txt
└── scripts/
    ├── master_pipeline.sh
    ├── premaster_diagnostic.sh                   (v2, corrected)
    └── spectral_delta.sh
```

---

## Carry-Forward Notes

- The base project snapshot still ships the **v1 `premaster_diagnostic.sh`** with the broken (empty) phase-correlation block. The v2 fix was reapplied this session. Open item: correct it at the snapshot/template level so it no longer needs restoring each session.
- This track is the new **darkest-top, lowest-LRA reference** in the family. Future dark-top siblings can use its segmented presence/brilliance/air EQ as the nearest reference, re-tuned to their own diagnostics.
- Stage E2 (lower-ceiling MP3 path) again proved necessary — the MP3 sat at −1.4 dBTP from the 0.82 ceiling; the 0.85 WAV ceiling alone would not guarantee MP3 compliance.
