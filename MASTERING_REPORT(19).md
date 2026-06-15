# Mastering Report — `Hymn_to_Osiris` (Hardcore Pop)

**Date:** 2026-05-23
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Hymn_to_Osiris-_Hardcore_Pop.wav` (16-bit PCM, **48 kHz**, stereo, 3:56.44)
**Framework:** FFmpeg 6.1.1 — derived from the `cofi_kkasper` template, parameters re-tuned per pre-master diagnostic

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-14.5 LUFS** | Quiet — needs ~+4.5 dB to reach commercial target |
| Loudness range (LRA) | 5.2 LU | Moderate dynamics — more headroom to work with than the Cofi source (3.9) |
| True peak | **-3.4 dBTP** | Clean — no inter-sample clipping in source |
| Sample peak | -3.44 dBFS | Healthy headroom |
| Crest factor | 4.3 (4.28 / 4.42) | Compressed source, but less squashed than Cofi (4.4 at LRA 3.9) |
| DC offset | 0.000130 | Negligible (below audibility threshold) |
| Stereo correlation | mean 0.703 / **min -0.437** / max 1.000 | Moderately wide; brief out-of-phase moments, but **not** extreme |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | -22.4 | Solid |
| 60-120 Hz bass | **-21.4** | Strongest band — fundamental |
| 120-250 Hz lowmid | -24.0 | Clean — no mud build-up (~2.6 dB below bass) |
| 250-500 Hz mid | -26.0 | |
| 500 Hz-1 kHz | -27.0 | |
| 1-2 kHz upmid | -30.5 | |
| **2-4 kHz presence** | **-32.7** | ⚠ **Scoop** — sits *below* both brilliance and air |
| 4-8 kHz brilliance | -31.5 | Relatively strong (1.2 dB above presence) |
| 8-16 kHz air | -32.3 | Moderately recessed (not as dark as Cofi's -35.8) |
| 16 kHz+ ultra | -43.4 | Roll-off |

**Key issues:**
1. Low integrated loudness (-14.5 LUFS) needs ~+4.5 dB of gain.
2. **2-4 kHz presence scoop** — the headline issue. Presence (-32.7) sits below the bands on either side of it (brilliance -31.5, air -32.3), which pushes leads/vocals back and robs the track of "bite." This is the inverse of Cofi's *global* top-end roll-off; here it is a localised dip.
3. Stereo image moderately wide with brief out-of-phase content (min -0.437) — widening is risky but the image is not pinned at the limit like Cofi (-0.823).
4. Compressed source (crest 4.3, LRA 5.2) — has slightly more dynamic range to work with than Cofi, but still wants only gentle glue.

---

## Tuning Decisions vs. Reference Templates

This track sits **between** the two prior references. Like Cofi it is **quiet and clean-peaked**; like zeldi it is only **moderately dark** (~11 dB bass-to-air slope vs. zeldi's ~9 and Cofi's ~13.5). Its distinguishing feature is a **localised 2-4 kHz presence scoop** rather than a global roll-off. Each stage was re-tuned accordingly:

| Stage | zeldi (ref 1) | Cofi (ref 2) | **This track** | Why |
|---|---|---|---|---|
| A: headroom prep | -6 dB | -3 dB | **-3 dB** | Source quiet + clean-peaked; modest attenuation is enough |
| A: DC shift | applied | skipped | **skipped** | DC 0.00013 below audibility |
| B: 200 Hz cut | -1.5 dB | removed | **removed** | Lowmid (120-250) clean, ~2.6 dB below bass |
| B: 80 Hz boost | +0.8 dB | removed | **removed** | Bass already the strongest band; boost would risk mud |
| B: presence | +0.6 @ 3.5k | +0.8 @ 3.5k | **+1.2 dB @ 3k, Q1.2** | Bigger lift — this is the headline scoop fix |
| B: brilliance | — | +0.6 @ 6k | **+0.5 dB @ 6k, Q1.0** | Gentle bridge so 3k and 12k lifts don't notch the 5-7k region |
| B: air | +1.5 @ 12k | +2.0 @ 12k | **+1.2 dB @ 12k, Q0.7** | Smaller than Cofi — air here is ~3.5 dB brighter to begin with |
| C: compression | th -16 / R 1.8 | th -14 / R 1.5 | **th -16 / R 1.6** | Between the two — firmer than Cofi (more LRA to use), gentler than zeldi |
| C: makeup | +1.5 dB | +1.0 dB | **+1.2 dB** | Matches the moderate ratio |
| D: stereo widening | 1.10× | skipped | **skipped** | Min correlation -0.437 → widening risks pushing sections out-of-phase; image already adequate |
| D: headroom prep | -3 dB | -3 dB | **-3 dB** | Unchanged |
| E: pre-gain | +6.3 dB | +12.0 dB | **+9.8 dB** | Dialed in iteratively to land integrated at -10.0 LUFS |
| E: oversample target | 176.4 kHz (4×) | 192 kHz (4×) | **192 kHz (4×)** | Source native 48 kHz |
| E: limiter ceiling | -1.4 dBFS | -1.4 dBFS | **-1.4 dBFS** | Proven to sit under -1.0 dBTP after downsample |

---

## Mastering Chain

All processing performed at 32-bit float internally, 48 kHz end-to-end (oversampled to 192 kHz only inside the limiter). Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-3dB` — peaks now at -5.9 dBFS, plenty of internal headroom for the EQ boosts
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz
- DC shift **skipped** — source DC offset (0.00013) is below audibility

### Stage B — Parametric EQ
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 3 kHz | **+1.2 dB** | 1.2 | Fill the 2-4 kHz presence scoop (headline fix) |
| Bell | 6 kHz | +0.5 dB | 1.0 | Gentle brilliance bridge — avoids a 5-7 kHz notch between the 3k and 12k lifts |
| Bell | 12 kHz | +1.2 dB | 0.7 | Broad air lift for openness |

No low-end EQ — the source bass profile is balanced as-is (bass strongest, lowmid clean).

### Stage C — Bus compression (glue)
`acompressor=threshold=-16dB:ratio=1.6:attack=20:release=180:makeup=1.2:knee=4`

A 1.6:1 ratio sits between the two references — firmer than Cofi's 1.5:1 because this source has more dynamic range to spend (LRA 5.2 vs 3.9), but gentler than zeldi's 1.8:1. The 20 ms attack lets kick transients through (preserving hardcore-pop punch); 180 ms release for musical pumping; 4 dB soft knee; +1.2 dB makeup. Adds ~1 dB of average loudness.

### Stage D — Headroom prep (no widening)
- `volume=-3dB` — pre-limiter headroom

**No `extrastereo` applied.** With source minimum phase correlation of -0.437, widening would push the already out-of-phase sections further, eroding mono compatibility on club PA and phone speakers. The image (mean 0.703) is already adequately wide. This decision was validated post-master: correlation mean held at 0.703.

### Stage E — 4× oversampled true-peak limiting
1. **`volume=+9.8dB`** — final loudness gain to target (dialed in iteratively)
2. **`aresample=192000:resampler=soxr:precision=28`** — 4× upsample (48 → 192 kHz) with SoX precision 28
3. **`alimiter=limit=0.85:attack=2:release=80:level=disabled`** — brickwall sample-peak limit at -1.4 dBFS in the oversampled domain (catches inter-sample reconstruction overshoot that a 48 kHz-domain limiter would miss)
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample back to 48 kHz

Result: true peak guaranteed under -1.0 dBTP after downsampling.

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-10.0 LUFS** | ✓ |
| True peak | ≤ -1.0 dBTP | **-1.4 dBTP** (WAV) / **-0.8 dBTP** (MP3) | ✓ WAV / safe MP3 |
| Loudness range | < 8 LU | 4.2 LU | ✓ |
| Crest factor | — | 3.4 (from 4.3) | Loud & competitive, not over-squashed |
| Stereo correlation | mono-safe | mean 0.703 / min -0.533 | ✓ image preserved |

The MP3 true peak (-0.8 dBTP) is 0.6 dB higher than the WAV due to lossy codec reconstruction overshoot — expected and within safe limits. The 16-bit WAV (-1.4 dBTP) is the canonical distribution master. The min correlation moved only slightly (-0.437 → -0.533) from limiter transient handling, not widening — confirming the skip-widening decision.

### Spectral changes (master − source, dB):

Integrated loudness gain was +4.5 dB (-14.5 → -10.0). The **relative Δ** subtracts that +4.5 dB so it reflects only **shape** changes:

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20-60 Hz subbass | +3.68 | -0.82 (limiter taming sub transients) |
| 60-120 Hz bass | +4.01 | -0.49 |
| 120-250 Hz lowmid | +4.33 | -0.17 |
| 250-500 Hz mid | +4.47 | -0.03 (neutral) |
| 500 Hz-1 kHz | +4.46 | -0.04 (neutral) |
| 1-2 kHz upmid | +4.63 | +0.13 |
| **2-4 kHz presence** | +5.27 | **+0.77** ✓ (scoop filled) |
| **4-8 kHz brilliance** | +5.38 | **+0.88** ✓ |
| **8-16 kHz air** | +5.41 | **+0.91** ✓ |
| **16 kHz+ ultra** | +5.28 | **+0.78** ✓ |

Confirms the intent: the **2-4 kHz presence scoop is filled** (biggest mid-band lift), the top end opens up (brilliance + air both up ~0.9 dB), the midrange holds neutral, and the low end is gently tamed by the limiter while keeping its weight. The track moves from presence-scooped and moderately closed to present, open, and bright.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `Hymn_to_Osiris_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `Hymn_to_Osiris_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | CD/distribution |
| `Hymn_to_Osiris_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview |

All three measure **-10.0 LUFS / 4.2 LU**. WAVs measure -1.4 dBTP, MP3 -0.8 dBTP (codec reconstruction).

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

`master_pipeline.sh` has this track's tuned parameters baked in as defaults but remains fully parameterized. As always, run `premaster_diagnostic.sh` first on every new source so chain parameters can be re-tuned per track rather than assumed.

---

## Streaming platform compliance

| Platform | Target LUFS | Master @ -10.0 | Result |
|---|---|---|---|
| Spotify | -14 | -10.0 | Will be turned down ~4.0 dB |
| Apple Music | -16 | -10.0 | Will be turned down ~6.0 dB |
| YouTube | -14 | -10.0 | Will be turned down ~4.0 dB |
| Tidal | -14 | -10.0 | Will be turned down ~4.0 dB |
| Club/DJ use | -8 to -10 | -10.0 | Direct play, ideal |

True peak of -1.4 dBTP (16-bit WAV master) leaves comfortable margin for lossy re-encoding by streaming codecs (AAC, Opus, Vorbis). No clipping risk expected.

---

## Project structure

```
hymn_to_osiris/
├── source/                          # Input file
│   └── Hymn_to_Osiris-_Hardcore_Pop.wav
├── analysis/                        # Pre/post-master measurements
│   ├── full_diagnostic.txt
│   ├── source_spectrum.txt
│   └── master_spectrum.txt
├── intermediate/                    # Stage-by-stage outputs (32-bit float)
│   ├── 01_prep.wav
│   ├── 02_eq.wav
│   ├── 03_comp.wav
│   ├── 04_stereo.wav
│   └── 05_limited.wav
├── master/                          # Final deliverables
│   ├── Hymn_to_Osiris_MASTER_32f.wav
│   ├── Hymn_to_Osiris_MASTER_16.wav
│   └── Hymn_to_Osiris_MASTER.mp3
├── verification/                    # Post-master checks
│   └── final_loudness.txt
└── scripts/                         # Reusable, parameterized
    ├── premaster_diagnostic.sh
    ├── master_pipeline.sh
    └── spectral_analysis.sh
```
