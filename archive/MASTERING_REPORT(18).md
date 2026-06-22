# Mastering Report — `Under_My_Spell`

**Date:** 2026-05-25
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Under_My_Spell_-_Hardcore_Pop.wav` (16-bit PCM, **48 kHz**, stereo, 3:09.92)
**Framework:** FFmpeg 6.1.1 — derived from `Hymn_to_Osiris` pipeline, parameters re-tuned per pre-master diagnostic
**Source note:** generative source (Suno export); already loud-ish, compressed, and dark — handled as a finished mix, mastered conservatively.

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-14.2 LUFS** | Quiet — needs ~+4 dB to reach commercial target |
| Loudness range (LRA) | **3.5 LU** | Tightest of any track to date — minimal dynamics to recover |
| True peak | **-3.26 dBTP** | Clean — no inter-sample clipping in source |
| Sample peak | -3.26 dBFS | Healthy headroom |
| Crest factor | 4.14 (12.34 dB) | Confirms a heavily compressed source |
| DC offset | 0.000183 | Negligible (below audibility threshold) |
| Stereo correlation | mean **0.724** / min **-0.589** / max 0.998 | Already wide; brief out-of-phase moments |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | -20.4 | Very strong |
| 60-120 Hz bass | -20.7 | Very strong — essentially tied with subbass |
| 120-250 Hz lowmid | -23.3 | Clean step down — no mud build-up |
| 250-500 Hz mid | -28.0 | Mids drop off sharply here |
| 500 Hz-1 kHz | -29.6 | |
| 1-2 kHz upmid | -30.7 | Lowest point — scooped midrange |
| 2-4 kHz presence | -30.4 | Flat with neighbours — **no presence scoop** |
| 4-8 kHz brilliance | -30.5 | |
| 8-16 kHz air | -32.0 | Recessed (~11.7 dB below subbass) |
| 16 kHz+ ultra | -42.6 | Steep roll-off — contributes to dark character |

**Key issues:**
1. Low integrated loudness (-14.2 LUFS) needs ~+4 dB of make-up gain.
2. **Bass-dominant, scooped-mid profile** — sub+bass nearly tied and very strong (-20.4 / -20.7), while everything from 250 Hz up sits 8-12 dB lower. A "smiley" balance.
3. **Dark/closed top** — top octave ~11.7 dB below subbass; air recessed.
4. **Tightest dynamics yet** (LRA 3.5, crest 4.14) — heavy further compression would over-squash.
5. Min phase correlation -0.589 → already wide with out-of-phase moments → **widening unsafe**.

---

## Tuning Decisions vs Reference Template (`Hymn_to_Osiris`)

`Hymn_to_Osiris` was tuned for a quiet, clean-peaked source with a **2-4 kHz presence scoop**. This track shares the quiet/clean-peaked profile but is **bass-dominant with no presence scoop and the tightest dynamics so far**. Each stage was re-tuned accordingly:

| Stage | Hymn (ref) | This track | Why |
|---|---|---|---|
| A: headroom prep | -3 dB | -3 dB | Source quiet; modest attenuation, plenty of EQ headroom |
| A: DC shift | skipped | **skipped** | DC 0.000183 below audibility |
| B: presence | +1.2 dB @ 3 kHz (fill *scoop*) | **+0.8 dB @ 3.5 kHz** | No scoop here → gentler, general vocal-clarity lift in a bass-heavy mix |
| B: brilliance | +0.5 dB @ 6 kHz | +0.5 dB @ 7 kHz | Sparkle bridge, nudged up to avoid the harsher 4-6 kHz region |
| B: air | +1.2 dB @ 12 kHz | **+1.5 dB @ 12 kHz** | Top is darker → slightly bigger broad air lift |
| B: low-end EQ | none | **none** | Sub/bass already strongest — preserve the intended weight |
| C: compression | th -16 / R 1.6 | **th -14 / R 1.4** | **Gentlest yet** — LRA only 3.5 LU; just cohesion, preserve dynamics |
| C: makeup | +1.2 dB | +1.0 dB | Filter minimum (`acompressor` makeup range is 1-64); lightest allowed |
| D: stereo widening | skipped | **skipped** | Min correlation -0.589 → widening risks mono fold-down |
| D: headroom prep | -3 dB | -3 dB | Unchanged |
| E: pre-gain | +9.8 dB | **+10.5 dB** | Tuned empirically (stage D measured -20.3 LUFS → +10.5 lands -10.0) |
| E: oversample target | 192 kHz (4×) | 192 kHz (4×) | Source native 48 kHz |
| E: limiter ceiling | -1.4 dBFS | -1.4 dBFS | Same — well under -1.0 dBTP after downsample |

---

## Mastering Chain

All processing performed at 32-bit float internally, 48 kHz end-to-end (oversampled to 192 kHz only inside the limiter). Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-3dB` — peaks move to ~-6.3 dBFS, leaving headroom for EQ boosts
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz (cleans rumble below the musical sub)

### Stage B — Parametric EQ (top-focused)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 3.5 kHz | +0.8 dB | 1.2 | Lift presence / vocal clarity in a bass-heavy mix |
| Bell | 7 kHz | +0.5 dB | 1.0 | Brilliance bridge (sparkle, avoids harsh 4-6 kHz) |
| Bell | 12 kHz | +1.5 dB | 0.7 | Broad air lift — open the dark top |

**No low-end EQ.** Sub and bass are already the strongest bands; boosting would worsen the bass dominance and risk a boomy limiter. The intended weight is preserved.

### Stage C — Bus compression (gentlest glue to date)
`acompressor=threshold=-14dB:ratio=1.4:attack=25:release=200:makeup=1.0:knee=4`

Lighter than every prior track (R 1.4 vs Hymn 1.6 / zeldi 1.8) because the source LRA is only 3.5 LU — the goal is cohesion, not loudness. 25 ms attack preserves kick transients (hardcore-pop punch); 200 ms release for musical pumping; `makeup=1.0` is the filter minimum. Adds ~1 dB of average loudness.

### Stage D — Headroom prep (no widening)
- `volume=-3dB` — pre-limiter headroom

**No `extrastereo` applied.** With source minimum phase correlation of -0.589, any widening would push the already out-of-phase sections further toward anti-phase and break mono compatibility. The source is already wide enough.

### Stage E — 4× oversampled true-peak limiting
1. **`volume=+10.5dB`** — final loudness gain to target (locked empirically against the -20.3 LUFS stage-D measurement)
2. **`aresample=192000:resampler=soxr:precision=28`** — 4× upsample (48 → 192 kHz) with SoX precision 28
3. **`alimiter=limit=0.85:attack=2:release=80:level=disabled`** — brickwall sample-peak limit at -1.4 dBFS in the oversampled domain (catches inter-sample reconstruction overshoot a sample-peak limiter would miss)
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample back to 48 kHz

Result: true peak guaranteed under -1.0 dBTP after downsampling.

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-10.0 LUFS** | ✓ |
| True peak | ≤ -1.0 dBTP | **-1.4 dBTP** (WAV) / **-1.0 dBTP** (MP3) | ✓ |
| Loudness range | < 8 LU | 2.9 LU | ✓ |

The MP3 true peak (-1.0 dBTP) is 0.4 dB higher than the WAV due to lossy-codec reconstruction overshoot — expected and exactly at the safe ceiling. The 16-bit WAV (-1.4 dBTP) is the canonical distribution master.

### Spectral changes (master − source, dB):

The "relative" column subtracts the +4.2 dB integrated-loudness gain, so it reflects only **shape** changes:

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20-60 Hz subbass | +3.64 | **-0.56** (limiter taming sub transients) |
| 60-120 Hz bass | +3.66 | **-0.54** |
| 120-250 Hz lowmid | +3.74 | -0.46 |
| 250-500 Hz mid | +3.98 | -0.22 |
| 500 Hz-1 kHz | +4.22 | +0.02 (neutral) |
| 1-2 kHz upmid | +4.40 | +0.20 |
| **2-4 kHz presence** | +4.86 | **+0.66** ✓ |
| **4-8 kHz brilliance** | +5.24 | **+1.04** ✓ |
| **8-16 kHz air** | +5.59 | **+1.39** ✓ |
| **16 kHz+ ultra** | +5.46 | **+1.26** ✓ |

Confirms the intent: top end opened (presence → air all lifted), midrange held neutral, and the very strong low end gently tamed by the limiter so it no longer dominates. The track moves from bass-heavy/dark to open and bright while preserving low-end weight.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `Under_My_Spell_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `Under_My_Spell_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | CD/distribution |
| `Under_My_Spell_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview |

All three measure **-10.0 LUFS / 2.9 LU**. WAVs measure -1.4 dBTP, MP3 -1.0 dBTP (codec reconstruction).

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

**`premaster_diagnostic.sh` updated to v2 in this project:** the STEREO PHASE CORRELATION block was rewritten. The previous grep-based approach silently produced **empty output** (it never captured `aphasemeter`'s running log) — visible in the saved diagnostics for `Hymn_to_Osiris` and earlier. It now aggregates the per-frame `lavfi.aphasemeter.phase` metadata into mean / min / max, which is the input that decides whether widening is safe. No other features were changed.

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
under_my_spell/
├── source/                          # Input file
│   └── Under_My_Spell_-_Hardcore_Pop.wav
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
│   ├── Under_My_Spell_MASTER_32f.wav
│   ├── Under_My_Spell_MASTER_16.wav
│   └── Under_My_Spell_MASTER.mp3
├── verification/                    # Post-master checks
│   └── final_loudness.txt
└── scripts/                         # Reusable, parameterized
    ├── premaster_diagnostic.sh      # v2 — phase correlation fixed
    ├── master_pipeline.sh
    └── spectral_analysis.sh
```
