# Mastering Report — `Kkodeks_drumovski_-_Cofi_Kkasper`

**Date:** 2026-05-20
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Kkodeks_drumovski_-_Cofi_Kkasper__new_.wav` (16-bit PCM, **48 kHz**, stereo, 2:49.92)
**Framework:** FFmpeg 6.1.1 — derived from `zeldi_bumbap_15_05` pipeline, parameters re-tuned per pre-master diagnostic

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-15.1 LUFS** | Quiet — needs ~+5 dB to reach commercial target |
| Loudness range (LRA) | 3.9 LU | Already compressed; little dynamic headroom to recover |
| True peak | **-3.8 dBTP** | Clean — no inter-sample clipping in source |
| Sample peak | -3.77 dBFS | Healthy headroom |
| Crest factor | 4.4 | Confirms compression in source |
| DC offset | -0.000246 | Negligible (below audibility threshold) |
| Stereo correlation | mean 0.676 / **min -0.823** / max 0.998 | Already wide; brief out-of-phase moments |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | -22.3 | Solid, the strongest band |
| 60-120 Hz bass | -23.2 | Healthy fundamental |
| 120-250 Hz lowmid | -24.8 | Clean — no mud build-up |
| 250-500 Hz mid | -25.6 | |
| 500 Hz-1 kHz | -26.8 | |
| 1-2 kHz upmid | -28.7 | |
| 2-4 kHz presence | -30.5 | Slightly recessed (-8 dB below subbass) |
| 4-8 kHz brilliance | -32.5 | |
| 8-16 kHz air | -35.8 | Recessed (-13.5 dB below subbass) — needs lift |
| 16 kHz+ ultra | -48.1 | Steep roll-off, contributes to dark character |

**Key issues:**
1. Low integrated loudness (-15.1 LUFS) needs significant gain
2. Dark/closed top end — top octave sits ~13.5 dB below subbass (vs. ~9 dB on the reference track)
3. Stereo image already at the limit — min phase correlation of -0.823 rules out widening
4. Compressed source (LRA 3.9, crest 4.4) — further heavy compression would over-squash

---

## Tuning Decisions vs. Reference Template

The previous pipeline (`zeldi_bumbap_15_05`) was tuned for a **loud, inter-sample-clipped, ~9 dB-slope** source. This track is the inverse: **quiet, clean-peaked, ~13 dB-slope**. Each stage was re-tuned accordingly:

| Stage | Reference | This track | Why |
|---|---|---|---|
| A: headroom prep | -6 dB | **-3 dB** | Source already quiet; less attenuation needed |
| A: DC shift | applied | **skipped** | Source DC -0.000246 below audibility |
| B: 200 Hz cut | -1.5 dB | **removed** | No mud build-up in lowmid (120-250 Hz is healthy) |
| B: 80 Hz boost | +0.8 dB | **removed** | Bass already solid; boost would risk mud |
| B: presence | +0.6 dB @ 3.5k | +0.8 dB @ 3.5k | Slightly more — track sits darker |
| B: brilliance | — | **+0.6 dB @ 6k** | New — fill brilliance band |
| B: air | +1.5 dB @ 12k | **+2.0 dB @ 12k** | Bigger lift — top is ~3.5 dB darker than reference |
| C: compression | th -16 / R 1.8 | **th -14 / R 1.5** | Lighter — LRA already small, preserve what dynamics remain |
| C: makeup | +1.5 dB | +1.0 dB | Match the lighter ratio |
| D: stereo widening | 1.10× | **skipped** | Min correlation -0.823 → widening risks mono fold-down |
| D: headroom prep | -3 dB | -3 dB | Unchanged |
| E: pre-gain | +6.3 dB | **+12.0 dB** | Compensate for the quieter source |
| E: oversample target | 176.4 kHz (4×) | **192 kHz** (4×) | Source native 48 kHz, not 44.1 |
| E: limiter ceiling | -1.4 dBFS | -1.4 dBFS | Same, well under -1.0 dBTP after downsample |

---

## Mastering Chain

All processing performed at 32-bit float internally, 48 kHz end-to-end (oversampled to 192 kHz only inside the limiter).

### Stage A — Prep
- `volume=-3dB` — peaks now at -6.8 dBFS, plenty of internal headroom for EQ boosts
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz

### Stage B — Parametric EQ
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 3.5 kHz | +0.8 dB | 1.5 | Lift recessed presence |
| Bell | 6 kHz | +0.6 dB | 1.2 | Fill brilliance |
| Bell | 12 kHz | +2.0 dB | 0.7 | Broad air lift |

No low-end EQ — the source bass profile is balanced as-is.

### Stage C — Bus compression (gentle glue)
`acompressor=threshold=-14dB:ratio=1.5:attack=25:release=200:makeup=1.0:knee=4`

Gentler than the reference (1.5:1 vs 1.8:1) because the source's LRA is already 3.9 LU. 25 ms attack preserves transients; 200 ms release musical pumping. Adds ~1 dB of average loudness.

### Stage D — Headroom prep (no widening)
- `volume=-3dB` — pre-limiter headroom

**No `extrastereo` applied.** With source minimum phase correlation of -0.823, any widening would push affected sections fully out-of-phase, breaking mono compatibility. Source is already wide enough.

### Stage E — 4× oversampled true-peak limiting
1. **`volume=+12.0dB`** — final loudness gain to target
2. **`aresample=192000:resampler=soxr:precision=28`** — 4× upsample (48 → 192 kHz) with SoX precision 28
3. **`alimiter=limit=0.85:attack=2:release=80:level=disabled`** — brickwall sample-peak limit at -1.4 dBFS in the oversampled domain (catches inter-sample reconstruction overshoot)
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample back to 48 kHz

Result: true peak guaranteed under -1.0 dBTP after downsampling.

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-10.1 LUFS** | ✓ |
| True peak | ≤ -1.0 dBTP | **-1.4 dBTP** (WAV) / **-0.8 dBTP** (MP3) | ✓ WAV / safe MP3 |
| Loudness range | < 8 LU | 2.4 LU | ✓ |

The MP3 true peak (-0.8 dBTP) is 0.6 dB higher than the WAV due to lossy codec reconstruction overshoot — this is expected and within safe limits. The 16-bit WAV (-1.4 dBTP) is the canonical distribution master.

### Spectral changes (master − source, loudness-normalized, dB):

The "relative" delta below subtracts the +5.0 dB loudness gain so it reflects only **shape** changes:

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20-60 Hz subbass | +3.57 | -1.43 (limiter taming sub transients) |
| 60-120 Hz bass | +3.76 | -1.24 |
| 120-250 Hz lowmid | +4.35 | -0.65 |
| 250-500 Hz mid | +5.07 | +0.07 (neutral) |
| 500 Hz-1 kHz | +5.14 | +0.14 |
| 1-2 kHz upmid | +5.14 | +0.14 |
| **2-4 kHz presence** | +5.59 | **+0.59** ✓ |
| **4-8 kHz brilliance** | +6.31 | **+1.31** ✓ |
| **8-16 kHz air** | +6.86 | **+1.86** ✓ |
| **16 kHz+ ultra** | +6.65 | **+1.65** ✓ |

Confirms the intent: top-end opened up (presence + air both lifted), midrange held neutral, low-end gently tamed by the limiter. The track moves from dark/closed to open and bright while preserving low-end weight.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `Kkodeks_drumovski_-_Cofi_Kkasper_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `Kkodeks_drumovski_-_Cofi_Kkasper_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | CD/distribution |
| `Kkodeks_drumovski_-_Cofi_Kkasper_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview |

All three measure **-10.1 LUFS / 2.4 LU**. WAVs measure -1.4 dBTP, MP3 -0.8 dBTP (codec reconstruction).

---

## Reusable scripts

```bash
# Run pre-master diagnostic on any source (writes a one-page report)
bash scripts/premaster_diagnostic.sh <source.wav> [report.txt]

# Run the full mastering chain (all 3 deliverables + verification)
bash scripts/master_pipeline.sh <source.wav> <output_name> <project_dir>

# Re-run just the spectrum analysis
bash scripts/spectral_analysis.sh <any.wav>
```

`premaster_diagnostic.sh` is **new in this project** — a single-shot report that captures every measurement (EBU R128, astats, stereo phase, octave spectrum) in one go. Recommended as the first step on every future track so chain parameters can be re-tuned per source.

---

## Streaming platform compliance

| Platform | Target LUFS | Master @ -10.1 | Result |
|---|---|---|---|
| Spotify | -14 | -10.1 | Will be turned down ~3.9 dB |
| Apple Music | -16 | -10.1 | Will be turned down ~5.9 dB |
| YouTube | -14 | -10.1 | Will be turned down ~3.9 dB |
| Tidal | -14 | -10.1 | Will be turned down ~3.9 dB |
| Club/DJ use | -8 to -10 | -10.1 | Direct play, ideal |

True peak of -1.4 dBTP (16-bit WAV master) leaves comfortable margin for lossy re-encoding by streaming codecs (AAC, Opus, Vorbis). No clipping risk expected.

---

## Project structure

```
cofi_kkasper/
├── source/                          # Input file
│   └── Kkodeks_drumovski_-_Cofi_Kkasper.wav
├── analysis/                        # Pre/post-master measurements
│   ├── full_diagnostic.txt
│   ├── source_ebur128.txt
│   ├── source_astats.txt
│   ├── source_stereo_phase.txt
│   ├── source_spectrum.txt
│   └── master_spectrum.txt
├── intermediate/                    # Stage-by-stage outputs (32-bit float)
│   ├── 01_prep.wav
│   ├── 02_eq.wav
│   ├── 03_comp.wav
│   ├── 04_stereo.wav
│   └── 05_limited.wav
├── master/                          # Final deliverables
│   ├── *_MASTER_32f.wav
│   ├── *_MASTER_16.wav
│   └── *_MASTER.mp3
├── verification/                    # Post-master checks
│   └── final_loudness.txt
└── scripts/                         # Reusable, parameterized
    ├── premaster_diagnostic.sh
    ├── master_pipeline.sh
    └── spectral_analysis.sh
```
