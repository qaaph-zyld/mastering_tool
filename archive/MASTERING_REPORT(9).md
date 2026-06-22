# Mastering Report — `natti_ohne_signal_dr_khans`

**Track:** Natti — *Ohne Signal* (Dr Khans)
**Date:** 2026-05-29
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Natti__Ohne_Signal__-_Dr_Khans.wav` (16-bit PCM, **48 kHz**, stereo, 3:05)
**Toolchain:** FFmpeg 6.1.1 (`equalizer`, `acompressor`, `extrastereo`, `aresample` w/ soxr, `alimiter`, `ebur128`, `astats`)

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-13.2 LUFS** | Quiet — has room to come up to target |
| Loudness range (LRA) | **3.5 LU** | Already narrow → compress gently |
| True peak | **-2.0 dBTP** | Clean, no inter-sample clipping |
| Sample peak | -2.0 dBFS | Headroom present |
| Crest factor | **~12.9 dB** | Punchy transients intact → preserve |
| DC offset | +0.000087 | Negligible (corrected anyway) |
| Stereo (side vs mid) | **-17.6 dB** | Narrow / mono-leaning → safe to widen |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | -20.9 | Solid |
| 60-120 Hz bass | **-20.4** | Strongest — fundamental |
| 120-250 Hz lowmid | -22.4 | Clean (no mud build-up) |
| 250-500 Hz mid | -24.5 | |
| 500 Hz-1 kHz | -25.7 | |
| 1-2 kHz upmid | -27.6 | |
| 2-4 kHz presence | -29.0 | Recessed |
| 4-8 kHz brilliance | -30.8 | |
| 8-16 kHz air | **-33.5** | Dark — top end rolled off |
| 16 kHz+ ultra | -44.7 | Steep roll-off |

**Key issues:** Quiet (−13.2 LUFS), tonally **dark** (presence + air recessed), and **narrow** stereo image. No clipping or mud to repair — this is a clean, under-finished mix that mainly needs level, top-end opening, and a touch of width.

> **Contrast with prior project (`zeldi_bumbap_15_05`):** that track was *too loud and inter-sample clipping* (+3.7 dBTP) and needed taming. This one is the opposite problem, so the house chain was re-tuned rather than applied as-is (see "Deviations" below).

---

## Mastering Chain

All processing at 32-bit float internally, **native 48 kHz preserved end-to-end**. Each stage keeps headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-6dB` — creates headroom (peak → −8.0 dBFS)
- `dcshift=-0.000087` — removes the small positive DC offset
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz

### Stage B — Parametric EQ (dark-mix profile)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 200 Hz | **−1.0 dB** | 1.2 | Gentle low-mid clean-up (lighter than house −1.5; source already clean) |
| Bell | 80 Hz | +0.8 dB | 1.4 | Reinforce fundamental bass |
| Bell | 3.5 kHz | **+1.2 dB** | 1.2 | Presence (raised vs house +0.6 — source was recessed) |
| Bell | 12 kHz | **+2.5 dB** | 0.7 | Broad air lift (raised vs house +1.5 — source was dark) |

### Stage C — Bus compression (gentle glue)
`acompressor=threshold=-18dB:ratio=1.5:attack=25:release=200:makeup=1.0:knee=4`

Source LRA was already 3.5 LU with a healthy ~12.9 dB crest, so glue is deliberately **light** (1.5:1 vs house 1.8:1, higher threshold, slower 25 ms attack) to preserve transient punch rather than squash it.

### Stage D — Stereo enhancement
- `extrastereo=m=1.12` — 12% widening (source side energy was −17.6 dB below mid, so widening is safe and beneficial)
- `volume=-3dB` — headroom prep for the limiter

### Stage E — 4× oversampled true-peak limiting (at 48 kHz)
Two parallel limit passes from the same Stage-D source:

1. **`volume=+13.2dB`** — final loudness gain, calibrated from the measured pre-limiter level (−22.7 LUFS) to land on −10 LUFS
2. **`aresample=192000:resampler=soxr:precision=28`** — upsample 4× (192 kHz = 4 × 48 kHz) with SoX high-precision resampler
3. **`alimiter=...:level=disabled`** — brickwall limit in the oversampled domain to catch inter-sample reconstruction overshoot
   - **Lossless masters:** ceiling `0.85` (≈ −1.4 dBTP final)
   - **MP3 source:** ceiling `0.82` (lower, see below)
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample back to native 48 kHz

---

## Iteration log (diagnostic-driven)

| Iter | Pre-gain | Ceiling | Result | Decision |
|---|---|---|---|---|
| 1 | +13.0 dB | 0.87 | WAV −10.0 LUFS / −1.2 dBTP. **MP3 → −0.9 dBTP** (over standard) | MP3 lossy overshoot exceeds −1.0 |
| 2 | +13.2 dB | 0.85 | WAV −9.9 / −1.4 dBTP. MP3 still −0.9 dBTP | Lowering WAV ceiling alone did **not** fix MP3 |
| 3 (MP3) | +13.2 dB | 0.80 | MP3 −1.7 dBTP / −10.2 LUFS | Compliant but 0.3 dB too quiet |
| **4 (final)** | **+13.2 dB** | **0.82** | **MP3 −1.4 dBTP / −10.1 LUFS** | ✓ compliant + loudness-matched |

**Finding:** MP3 (libmp3lame) generates its own filterbank reconstruction peaks that are **largely independent of the source WAV ceiling**. The fix is a **dedicated, slightly lower-ceiling limiter pass for the MP3 path only** — the lossless masters keep the louder −1.4 dBTP ceiling. This is now baked into the pipeline (Stage E2).

---

## Final Master Metrics

| Metric | Target | Actual (WAV) | Actual (MP3) | Status |
|---|---|---|---|---|
| Integrated loudness | −10.0 LUFS | **−9.9 LUFS** | **−10.1 LUFS** | ✓ |
| True peak | ≤ −1.0 dBTP | **−1.4 dBTP** | **−1.4 dBTP** | ✓ |
| Loudness range | < 8 LU | 2.3 LU | 2.3 LU | ✓ (tight, by design at this target) |

Overall broadband gain applied: **+2.86 dB** (RMS −14.9 → −12.0 dB); integrated loudness lift **+3.3 dB** (−13.2 → −9.9 LUFS).

### Spectral changes — tonal shaping (master − source, normalised for the +2.86 dB broadband gain):

| Band | Δ (tonal) | Read |
|---|---|---|
| 20-60 Hz subbass | −0.3 | Held in check |
| 60-120 Hz bass | −0.4 | Held in check |
| 120-250 Hz lowmid | −0.4 | Cleaned |
| 250-500 Hz mid | 0.0 | Neutral |
| 500 Hz-1 kHz | +0.4 | |
| 1-2 kHz upmid | +0.7 | |
| **2-4 kHz presence** | **+1.4** | Lifted |
| 4-8 kHz brilliance | +1.9 | Lifted |
| **8-16 kHz air** | **+2.5** | Opened up |
| 16 kHz+ ultra | +2.6 | Opened up |

The dark source has been opened up: presence and air are substantially lifted while the low end is held steady, yielding a brighter, clearer, more finished master without thinning the bass.

---

## Deviations from the house (44.1 kHz) pipeline

| Parameter | House default | This master | Reason |
|---|---|---|---|
| Sample rate | 44.1 kHz | **48 kHz native** | Preserve source rate; oversample 192 kHz |
| 200 Hz cut | −1.5 dB | −1.0 dB | Source low-mids already clean |
| Presence (3.5k) | +0.6 dB | +1.2 dB | Source recessed |
| Air (12k) | +1.5 dB | +2.5 dB | Source dark |
| Compression | 1.8:1 @ −16 | 1.5:1 @ −18 | Source LRA already low; preserve crest |
| Widening | 10% | 12% | Source narrow |
| Pre-gain | +6.3 dB | +13.2 dB | Source 3.7 dB quieter |
| MP3 path | shared limiter | **dedicated lower ceiling** | Lossy true-peak safety |

---

## Deliverables

| File | Format | Loudness / True peak | Use |
|---|---|---|---|
| `natti_ohne_signal_dr_khans_MASTER_32f.wav` | 32-bit float, 48 kHz | −9.9 LUFS / −1.4 dBTP | Archival, future re-encoding |
| `natti_ohne_signal_dr_khans_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | −9.9 LUFS / −1.4 dBTP | Distribution |
| `natti_ohne_signal_dr_khans_MASTER.mp3` | 320 kbps CBR, joint stereo | −10.1 LUFS / −1.4 dBTP | Streaming / preview |

> A 44.1 kHz set can be produced on request (adds one soxr SRC stage); 48 kHz is kept here to avoid an unnecessary resample of the source.

---

## Reusable script

`scripts/master_pipeline_48k.sh` reproduces the entire chain (verified end-to-end from source):

```bash
bash scripts/master_pipeline_48k.sh <source.wav> <output_name> <project_dir>
```

Supporting scripts: `scripts/premaster_diagnostic.sh` (full measurement report), `scripts/spectral_analysis.sh`.

---

## Streaming platform compliance

| Platform | Target LUFS | Master @ −9.9 | Result |
|---|---|---|---|
| Spotify | −14 | −9.9 | Turned down ~4.1 dB to −14 |
| Apple Music | −16 | −9.9 | Turned down ~6.1 dB |
| YouTube | −14 | −9.9 | Turned down ~4.1 dB |
| Tidal | −14 | −9.9 | Turned down ~4.1 dB |
| Club/DJ use | −8 to −10 | −9.9 | Direct play, ideal |

True peak at −1.4 dBTP leaves margin so no clipping occurs even after lossy AAC/Opus re-encoding by streaming services.

---

## Project structure

```
natti_ohne_signal_dr_khans/
├── source/        natti_ohne_signal_dr_khans.wav        (staged source)
├── analysis/      premaster_diagnostic.txt, postmaster_spectral.txt
├── intermediate/  01_prep → 02_eq → 03_comp → 04_stereo → 05_limited(+mp3src)
├── master/        32f WAV, 16-bit WAV, 320 MP3
├── verification/  final_loudness.txt
└── scripts/       master_pipeline_48k.sh, premaster_diagnostic.sh, spectral_analysis.sh
```
