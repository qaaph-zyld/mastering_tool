# Mastering Report — `Master_of_Boredom` (Hardcore Pop)

**Date:** 2026-05-29
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Master_of_Boredom_-_Hardcore_Pop.wav` — 16-bit PCM, 48 kHz, stereo, 4:08 (248.44 s)
**Toolchain:** FFmpeg 6.1.1 (soxr resampler, libmp3lame), 100% open-source

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-14.3 LUFS** | Quiet for the genre — needs ~+4.5 dB to be competitive |
| Loudness range (LRA) | **2.1–2.9 LU** | Very low — track is already dynamically tight |
| True peak | **-4.1 dBTP** | Clean; no inter-sample overshoot, generous headroom |
| Sample peak | -4.1 dBFS | Matches true peak (no reconstruction overshoot) |
| Crest factor | ~11.1 dB | Transients present, but macro-dynamics minimal |
| DC offset | +0.00007 | Negligible — no correction needed |
| Flat (clip) factor | 0.0 | No clipping in source |
| Mid / Side RMS | -15.4 / -32.0 dB | **16.6 dB gap → narrow, mono-centric image** |

### Spectral balance (octave bands, RMS dB)

| Band | RMS | Read |
|---|---|---|
| 20–60 Hz subbass | **-19.4** | Loudest band — slightly sub-dominant |
| 60–120 Hz bass | -20.5 | Strong fundamental |
| 120–250 Hz lowmid | -23.8 | |
| 250–500 Hz mid | -28.3 | Scoop begins |
| 500 Hz–1 kHz | -29.7 | |
| 1–2 kHz upmid | -30.4 | |
| 2–4 kHz presence | **-30.6** | Recessed — lacks clarity/energy |
| 4–8 kHz brilliance | **-31.5** | Recessed — lacks edge |
| 8–16 kHz air | **-33.8** | Thin — lacks sheen |
| 16 kHz+ ultra | -44.4 | Natural roll-off |

**Key issues:** (1) too quiet for the genre; (2) **dark / recessed mids and highs** — a 13.3 dB tilt from bass to air; (3) slightly **sub-dominant** low end; (4) **narrow** stereo image. The low LRA (2.1–2.9) means heavy compression would be pointless and risk distortion — loudness must come from clean gain + true-peak limiting, not crushing.

> **Note vs previous project (`zeldi_bumbap`):** that track was loud with low-mid mud and needed cutting. This track is the inverse — quiet, dark, and recessed. The chain below is re-tuned accordingly; the previous EQ/compression settings were **not** reused.

---

## Mastering Chain

All processing performed at 32-bit float internally. Each stage maintains headroom; no clipping occurs until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-2dB` — modest headroom (source already peaks at -4.1 dBFS) for the EQ boosts
- `highpass=f=30:poles=2` — 12 dB/oct subsonic filter at 30 Hz (removes rumble; kick/sub fundamentals preserved)
- *DC correction skipped* — offset is +0.00007, audibly and technically negligible

### Stage B — Parametric EQ
| Filter | Freq | Gain | Q / type | Purpose |
|---|---|---|---|---|
| Bell | 40 Hz | **-1.0 dB** | 0.9 | Tame slight sub dominance before loudness push |
| Bell | 2.8 kHz | **+1.2 dB** | 1.2 | Restore presence / clarity |
| Bell | 6 kHz | **+1.2 dB** | 1.0 | Add definition / edge |
| High shelf | 11 kHz | **+2.5 dB** | 0.7 | Lift air / sheen |

Post-EQ peak: -4.9 dBFS (boosts offset by the sub tuck + prep cut — headroom intact).

### Stage C — Bus compression (glue)
`acompressor=threshold=-18dB:ratio=1.5:attack=25:release=200:makeup=1:knee=6`

Deliberately gentle — 1.5:1 ratio, high threshold, 25 ms attack to preserve transients. With source LRA already ~2.9 LU this is for cohesion only, not level. ~1 dB makeup.

### Stage D — Stereo enhancement
- `extrastereo=m=1.12` — 12% widening (justified by the narrow 16.6 dB mid/side gap)
- `volume=-3dB` — headroom prep for the limiter

Post-check: mid/side gap remained healthy at **13.4 dB** (side still well below mid) — wider image, full mono compatibility, no phase risk.

### Stage E — 4× oversampled true-peak limiting
1. `volume=+11.5dB` — final loudness gain to target (calibrated, see below)
2. `aresample=192000:resampler=soxr:precision=28` — **4× upsample** for this 48 kHz source via SoX high-precision resampler
3. `alimiter=limit=0.85:attack=2:release=80:level=disabled` — brickwall at -1.41 dBFS in the oversampled domain (catches inter-sample reconstruction overshoot a sample-peak limiter would miss)
4. `aresample=48000:resampler=soxr:precision=28` — downsample back to native 48 kHz

Result: true peak guaranteed at **-1.40 dBTP** after downsampling.

#### Pre-gain calibration (iterative)
Measured end of Stage D = -20.7 LUFS. Limiter pre-gain swept and verified:

| Pre-gain | Integrated | True peak |
|---|---|---|
| +10.5 dB | -10.3 LUFS | -1.40 dBTP |
| +11.0 dB | -10.0 LUFS | -1.40 dBTP |
| **+11.5 dB** | **-9.7 LUFS** | **-1.40 dBTP** |

Selected **+11.5 dB → -9.7 LUFS** — the competitive end for Hardcore Pop while the oversampled limiter holds true peak constant at -1.40 dBTP.

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | ~-9.8 LUFS | **-9.7 LUFS** | ✓ |
| True peak (WAV) | ≤ -1.0 dBTP | **-1.40 dBTP** | ✓ |
| Loudness range | tight OK | 2.1 LU | ✓ (genre-appropriate) |

### Spectral change — relative tonal reshaping (master − source, normalized to sub-bass)

| Band | Relative Δ |
|---|---|
| 20–60 Hz subbass | 0.0 (reference) |
| 60–120 Hz bass | +0.4 |
| 120–250 Hz lowmid | +1.1 |
| 250–500 Hz mid | +1.5 |
| 500 Hz–1 kHz | +1.8 |
| 1–2 kHz upmid | +2.2 |
| **2–4 kHz presence** | **+2.8** |
| **4–8 kHz brilliance** | **+3.0** |
| **8–16 kHz air** | **+3.2** |
| 16 kHz+ ultra | +3.6 |

The master is meaningfully brighter and clearer: presence, edge, and air lifted ~3 dB relative to the low end. The bass→air tilt tightened from 13.3 dB to 10.5 dB — dark/recessed source reshaped into a balanced, modern Hardcore Pop tonality while the low end keeps its weight.

---

## Deliverables

| File | Format | Use | Measured |
|---|---|---|---|
| `Master_of_Boredom_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding | -9.7 LUFS / -1.40 dBTP |
| `Master_of_Boredom_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | Distribution | -9.7 LUFS / -1.40 dBTP |
| `Master_of_Boredom_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming / preview | -9.7 LUFS / -0.79 dBTP |

> The MP3's true peak rose to -0.79 dBTP — expected, as lossy encoding adds its own inter-sample overshoot. The WAVs' -1.40 dBTP ceiling is precisely the headroom that absorbs this and keeps the MP3 under 0 dBFS (no clipping).

---

## Reusable script

`scripts/master_pipeline.sh` reproduces the entire chain (verified — regenerates -9.7 LUFS / 2.1 LU identically):

```bash
bash scripts/master_pipeline.sh source/Master_of_Boredom.wav Master_of_Boredom .
```

Diagnostics: `scripts/premaster_diagnostic.sh <src> [report]` and `scripts/spectral_analysis.sh <src>`.

---

## Streaming platform compliance

| Platform | Target LUFS | Master @ -9.7 | Result |
|---|---|---|---|
| Spotify | -14 | -9.7 | Turned down ~4.3 dB to -14 |
| Apple Music | -16 | -9.7 | Turned down ~6.3 dB |
| YouTube | -14 | -9.7 | Turned down ~4.3 dB |
| Tidal | -14 | -9.7 | Turned down ~4.3 dB |
| Club / DJ use | -8 to -10 | -9.7 | Direct play, ideal |

True peak at -1.40 dBTP (WAV) means no clipping even after platform AAC/Opus re-encoding.

---

## Project structure

```
MasterOfBoredom/
├── source/         Master_of_Boredom.wav (original)
├── analysis/       premaster_diagnostic.txt
├── intermediate/   01_prep → 05_limited (per-stage, auditable)
├── master/         3 deliverables
├── verification/   final_loudness.txt, spectral_delta.txt
└── scripts/        master_pipeline.sh, premaster_diagnostic.sh, spectral_analysis.sh
```
