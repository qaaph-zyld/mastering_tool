# Mastering Report — `how_it_ends_up_hardcore_pop`

**Date:** 2026-05-29
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `How_it_ends_up_Hardcore_Pop_2.wav` (16-bit PCM, 48 kHz, stereo, 3:57)
**Genre:** Hardcore Pop
**Targets:** −9.5 LUFS integrated · ≤ −1.0 dBTP true peak (all deliverables)

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **−13.0 LUFS** | Moderate; room to push for the genre |
| Loudness range (LRA) | 6.3 LU | Healthy dynamics |
| True peak | **−0.2 dBTP** | Clean — no inter-sample clipping to repair |
| Sample peak | −0.21 / −0.31 dBFS (L/R) | Near full-scale, not over |
| RMS level | −14.7 dB | — |
| Crest factor | ~14.5 dB | Strong transient punch |
| DC offset | −0.000309 | Tiny; corrected in prep |
| Phase correlation | mean +0.52, min −0.52, max +1.0 | Mono-safe; widening kept conservative |
| Mid vs Side RMS | −15.0 vs −26.3 dB (~11 dB) | Fairly narrow image |

### Spectral balance (octave bands, RMS dB)

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | −20.7 | Solid |
| 60-120 Hz bass | **−20.0** | Strongest — fundamental |
| 120-250 Hz lowmid | −22.3 | Clean (not muddy) |
| 250-500 Hz mid | −23.3 | |
| 500 Hz-1 kHz | −25.1 | |
| 1-2 kHz upmid | −29.5 | Falling away |
| 2-4 kHz presence | **−32.6** | Weakest — recessed |
| 4-8 kHz brilliance | −31.9 | Dark |
| 8-16 kHz air | −30.8 | Dark |
| 16 kHz+ ultra | −41.7 | Roll-off |

**Key reads:** Bass-forward, mid-scooped mix with a ~12 dB drop from bass to presence. Top end (presence → air) is recessed. For hardcore pop — which needs brightness and bite to cut through — the chain lifts presence/brilliance/air while preserving the bass foundation. True peak is already clean (no clipping repair needed), and dynamics/phase are healthy.

---

## Mastering Chain

All processing performed at 32-bit float internally, **48 kHz native end-to-end**. Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-6dB` — creates headroom
- `dcshift=0.000309` — removes DC offset
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz

### Stage B — Parametric EQ (dark-mix profile)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 250 Hz | **−1.0 dB** | 1.2 | Gentle low-mid clean-up for clarity |
| Bell | 2.8 kHz | **+2.5 dB** | 1.0 | Lift recessed presence (weakest band; leads/vocals) |
| Bell | 6 kHz | +1.5 dB | 1.2 | Brilliance / hardcore bite |
| Bell | 12 kHz | +2.5 dB | 0.7 | Broad air lift (top end was rolled off) |

### Stage C — Glue bus compression
`acompressor=threshold=-18dB:ratio=2:attack=15:release=180:makeup=2:knee=4`

2:1 ratio with a fast 15 ms attack preserves transient snap (essential for hardcore punch); 180 ms release for musical recovery; 4 dB soft knee; +2 dB makeup.

### Stage D — Stereo enhancement
- `extrastereo=m=1.08` — modest 8% widening (kept conservative because source phase already dips to −0.52)
- `volume=-3dB` — headroom prep for limiter

Post-check: phase mean +0.49, min −0.58 — essentially unchanged from source. Wider but mono-safe.

### Stage E — 4× oversampled true-peak limiting
Pre-limiter measured **−16.9 LUFS / −2.8 dBTP**. Pre-gain was calibrated empirically by bracketing:

| Pre-gain | Integrated | LRA | True Peak |
|---|---|---|---|
| **+9.0 dB** (chosen) | **−9.5 LUFS** | **3.6 LU** | −1.4 dBTP |
| +10.5 dB | −9.0 LUFS | 3.0 LU | −1.4 dBTP |
| +12.0 dB | −8.6 LUFS | 2.5 LU | −1.4 dBTP |

**+9.0 dB chosen** — loud and competitive for the genre while retaining the most transient life (LRA 3.6, vs the over-squashed 2.5 at +12 dB).

Limiter chain (per deliverable target):
1. `volume=+9.0dB` — calibrated loudness gain
2. `aresample=192000:resampler=soxr:precision=28` — upsample 4× (SoX high-precision)
3. `alimiter=limit=<ceiling>:attack=2:release=80:level=disabled` — brickwall in the oversampled domain (catches inter-sample reconstruction overshoot)
4. `aresample=48000:resampler=soxr:precision=28` — downsample back

Two limiter passes: **ceiling 0.85** (≈ −1.4 dBTP) for the WAV masters; **ceiling 0.82** for the MP3 source so lossy-encode overshoot stays ≤ −1.0 dBTP.

---

## Final Master Metrics

| Metric | Target | 32f / 16-bit | MP3 | Status |
|---|---|---|---|---|
| Integrated loudness | −9.5 LUFS | **−9.5 LUFS** | −9.7 LUFS | ✓ |
| True peak | ≤ −1.0 dBTP | **−1.4 dBTP** | **−1.1 dBTP** | ✓ |
| Loudness range | — | 3.6 LU | 3.4 LU | ✓ |

### Spectral changes (master − source, dB)

| Band | Δ | Read |
|---|---|---|
| 20-60 Hz subbass | +2.7 | |
| 60-120 Hz bass | +2.6 | Foundation preserved |
| 120-250 Hz lowmid | +2.6 | |
| 250-500 Hz mid | +3.3 | |
| 500 Hz-1 kHz | +3.7 | Scoop filling in |
| 1-2 kHz upmid | +4.1 | |
| **2-4 kHz presence** | **+5.3** | Recessed band lifted |
| **4-8 kHz brilliance** | **+5.4** | Bite added |
| **8-16 kHz air** | **+5.4** | Top opened up |
| 16 kHz+ ultra | +5.3 | |

Although every band rose with the loudness gain, the presence/brilliance/air region rose ~2.7 dB **more** than the bass. The bass-to-presence gap narrowed from ~12 dB (source) to ~9.5 dB (master): the master is brighter and more balanced while keeping its low-end weight.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `how_it_ends_up_hardcore_pop_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `how_it_ends_up_hardcore_pop_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | Distribution |
| `how_it_ends_up_hardcore_pop_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming / preview |

All deliverables verified at full source duration (3:57.7).

---

## Reusable script

`scripts/master_pipeline_hardcore.sh` reproduces the entire chain:

```bash
bash scripts/master_pipeline_hardcore.sh <source.wav> <output_name> <project_dir>
```

Tunable parameters are exposed at the top of the script (`PREGAIN_DB`, `LIMIT_LOSSLESS`, `LIMIT_MP3`, `OS_RATE`, `NATIVE_RATE`).

## Streaming platform compliance

| Platform | Target LUFS | Master @ −9.5 | Result |
|---|---|---|---|
| Spotify | −14 | −9.5 | Turned down ~4.5 dB to −14 |
| Apple Music | −16 | −9.5 | Turned down ~6.5 dB |
| YouTube | −14 | −9.5 | Turned down ~4.5 dB |
| Tidal | −14 | −9.5 | Turned down ~4.5 dB |
| Club/DJ use | −8 to −10 | −9.5 | Direct play, ideal |

True peak at −1.4 dBTP (WAV) / −1.1 dBTP (MP3) ensures no clipping even after lossy re-encoding (AAC/Opus) by streaming services.

---

## Project structure

```
how_it_ends_up_hardcore_pop_project/
├── source/         how_it_ends_up_hardcore_pop.wav        (original)
├── analysis/       premaster_diagnostic.txt
├── intermediate/   01_prep → 05_limited (+ mp3src)        (stage-by-stage WAVs)
├── master/         3 deliverables (32f / 16 / mp3)
├── verification/   final_loudness.txt, spectral_comparison.txt
└── scripts/        master_pipeline_hardcore.sh, premaster_diagnostic.sh,
                    spectral_analysis.sh, verify_spectral.sh
```
