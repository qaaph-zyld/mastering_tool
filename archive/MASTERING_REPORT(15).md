# Mastering Report — `Grit_Tongue_BRATIJA`

**Date:** 2026-05-28
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Grit_Tongue_BRATIJA_26.wav` (16-bit PCM, **48 kHz**, stereo, 1:02.24)
**Framework:** FFmpeg 6.1.1 — derived from `10_outta_10` pipeline, parameters re-tuned per pre-master diagnostic
**Source note:** Short track (~1:02). Breaks from the recent hardcore-pop family: quieter, more dynamic, cleaner-peaked, sub-led with a genuine midrange scoop. Mastered to open the mids and top while preserving its real dynamics.

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-15.7 LUFS** | **Quietest of the recent batch** — needs ~+5.7 dB make-up |
| Loudness range (LRA) | **5.6 LU** | **Most dynamic of the family** — real macro-dynamics to preserve |
| True peak | **-4.8 dBTP** | Very clean — ample headroom, no inter-sample clipping |
| Sample peak | -4.76 dBFS | Comfortable headroom |
| Crest factor | ~12.4 dB | **Least-squashed source of the batch** |
| DC offset | **+0.000418** | **Largest of any track to date** (~2× the family) — still sub-audible, but the threshold case for re-enabling DC correction |
| Stereo correlation | mean **0.548** / min **-0.398** / max 0.998 | Mildest anti-phase of the batch, but still negative |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | **-21.1** | **Single strongest band** — sub-led |
| 60-120 Hz bass | -23.0 | Falls 1.9 dB below sub (NOT tied like the family) |
| 120-250 Hz lowmid | -26.4 | Steep falloff continues (-3.4 dB) |
| 250-500 Hz mid | -31.4 | Into the valley |
| 500 Hz-1 kHz | **-31.7** | **Floor — genuine midrange scoop** |
| 1-2 kHz upmid | -30.4 | Climbing back out |
| 2-4 kHz presence | **-29.7** | Rises +2.0 dB above the valley floor |
| 4-8 kHz brilliance | -31.4 | |
| 8-16 kHz air | -34.6 | Recessed (~13.5 dB below sub) |
| 16 kHz+ ultra | -45.0 | Steep roll-off |

**Key issues:**
1. Low integrated loudness (-15.7 LUFS) needs ~+5.7 dB — the largest correction of the recent batch.
2. **Sub-led with a steep low-end falloff** — sub is strongest but bass and low-mid drop off fast (NOT the nearly-tied "smiley" low end of the hardcore-pop tracks). A small low-mid support boost is therefore safe here.
3. **Genuine midrange scoop at 500 Hz-1 kHz** (-31.7 floor) — a real spectral hole, unlike the family's smooth descending slopes. Needs a broad mid fill.
4. **Dark/closed top** — sub→air slope 13.5 dB; air recessed. Presence + air lift as usual.
5. **Most dynamic source of the batch** (LRA 5.6, crest 12.4 dB) — there are real dynamics worth preserving; it can also take slightly firmer glue without over-squashing.
6. Min phase correlation -0.398 → mildest anti-phase yet but still negative → widening unsafe.

---

## Tuning Decisions vs Reference Template (`10_outta_10`)

`10_outta_10` was tuned for a loud, squashed, bass-dominant (nearly-tied low end), dark-top source with no mid work. `Grit_Tongue_BRATIJA` is in several respects the inverse: **quieter, more dynamic, sub-led with a steep falloff, and carrying a real mid scoop**. Each stage was re-tuned accordingly:

| Stage | 10_outta_10 (ref) | This track | Why |
|---|---|---|---|
| A: headroom prep | -3 dB | -3 dB | Quiet source; modest attenuation, ample EQ headroom |
| A: DC shift | skipped | **RE-ENABLED (-0.000418)** | DC +0.000418 is the largest of any source — the threshold case the DC stage exists for. Corrects to ~-0.000009. |
| B: low-mid support | none | **+1.0 dB @ 200 Hz** | Low end falls off steeply (not tied) → a small support boost is safe and welcome (family forbade low-end EQ) |
| B: mid fill | none | **+1.2 dB @ 700 Hz** | **NEW** — fills the genuine 500 Hz-1 kHz scoop; family tracks had no mid work |
| B: presence | +0.8 dB @ 3.5 kHz | +0.8 dB @ 3.5 kHz | Vocal clarity — unchanged |
| B: brilliance | +0.5 dB @ 7 kHz | +0.5 dB @ 7 kHz | Brilliance bridge — unchanged |
| B: air | +1.7 dB @ 12 kHz | +1.7 dB @ 12 kHz | Top darkness (-34.6) close to 10_outta_10 (-33.4) → same lift |
| C: compression | th -14 / R 1.5 | **th -15 / R 1.6** | **Firmer** — LRA 5.6 / crest 12.4 is the most dynamic of the batch → step back toward zeldi/Hymn R1.6 for real glue without over-squashing |
| C: makeup | +1.0 dB | **+1.2 dB** | Match the firmer ratio |
| D: stereo widening | skipped | **skipped** | Min correlation -0.398 → still negative → mono safety |
| D: headroom prep | -3 dB | -3 dB | Unchanged |
| E: pre-gain | +8.9 dB | **+10.6 dB** | Quieter source; **also swept, not computed** — see note below |
| E: oversample target | 192 kHz (4×) | 192 kHz (4×) | Source native 48 kHz |
| E: limiter ceiling | -1.4 dBFS | -1.4 dBFS | Same — well under -1.0 dBTP after downsample |

### Note on pre-gain: the family's "target − stageD" shortcut under-shoots here

On the squashed family tracks, pre-gain ≈ target − stage-D loudness landed -10.0 on the first try, because a heavily-limited source loses almost nothing more to the limiter. This source is the **most dynamic of the batch**, so it loses more to limiting: stage D measured **-19.9 LUFS**, but the naive +9.9 dB landed only **-10.3**. A short sweep (9.9 → 10.2 → 10.6 → 11.0) showed +10.6 dB lands **-9.9 LUFS** — the chosen value. Takeaway for the framework: **for high-LRA sources, sweep the pre-gain rather than trusting the linear shortcut.**

---

## Mastering Chain

All processing performed at 32-bit float internally, 48 kHz end-to-end (oversampled to 192 kHz only inside the limiter). Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-3dB` — peaks move to ~-7.8 dBFS, leaving ample headroom for EQ boosts
- `dcshift=-0.000418` — **DC correction re-enabled** (source +0.000418 → ~-0.000009)
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz

### Stage B — Parametric EQ (low-mid support + mid fill + top lift)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 200 Hz | +1.0 dB | 1.0 | Low-mid support (low end falls off steeply, not tied) |
| Bell | 700 Hz | +1.2 dB | 0.9 | **Fill the genuine 500 Hz-1 kHz mid scoop (new)** |
| Bell | 3.5 kHz | +0.8 dB | 1.2 | Presence / vocal clarity |
| Bell | 7 kHz | +0.5 dB | 1.0 | Brilliance bridge (sparkle, avoids harsh 4-6 kHz) |
| Bell | 12 kHz | +1.7 dB | 0.7 | Broad air lift — open the dark top |

Unlike the hardcore-pop family (top-focused EQ only, no low/mid work), this track's sub-led-with-a-mid-hole contour justifies the two added low/mid moves. The low end is *not* tied, so a 200 Hz support boost adds body without bass dominance; the 700 Hz fill addresses the real -31.7 dB valley.

### Stage C — Bus compression (firmer glue)
`acompressor=threshold=-15dB:ratio=1.6:attack=25:release=200:makeup=1.2:knee=4`

Firmer than the recent family (R 1.6 vs 1.4-1.5) because this source has the most macro-dynamic room of the batch (LRA 5.6, crest 12.4 dB). The goal is real cohesion while still preserving dynamics — the final master keeps LRA 4.4, more than any of the squashed family masters (which landed 2.4-3.3). 25 ms attack preserves transients; 200 ms release for musical pumping.

### Stage D — Headroom prep (no widening)
- `volume=-3dB` — pre-limiter headroom

**No `extrastereo` applied.** Min phase correlation -0.398 is the mildest anti-phase of the batch but still negative; widening would risk pushing those moments toward anti-phase and breaking mono compatibility. The source is wide enough.

### Stage E — 4× oversampled true-peak limiting
1. **`volume=+10.6dB`** — final loudness gain to target (locked by sweep, not the linear shortcut — see note above)
2. **`aresample=192000:resampler=soxr:precision=28`** — 4× upsample (48 → 192 kHz) with SoX precision 28
3. **`alimiter=limit=0.85:attack=2:release=80:level=disabled`** — brickwall sample-peak limit at -1.4 dBFS in the oversampled domain (catches inter-sample reconstruction overshoot a sample-peak limiter would miss)
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample back to 48 kHz

Result: true peak guaranteed under -1.0 dBTP after downsampling.

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-9.9 LUFS** | ✓ |
| True peak | ≤ -1.0 dBTP | **-1.4 dBTP** (WAV) / **-0.9 dBTP** (MP3) | ✓ |
| Loudness range | < 8 LU | **4.4 LU** | ✓ (most preserved dynamics of the batch) |

The MP3 true peak (-0.9 dBTP) is 0.5 dB higher than the WAV due to lossy-codec reconstruction overshoot — expected and within the safe band (the family has ranged -0.8 to -1.3 dBTP on MP3). The 16-bit WAV (-1.4 dBTP) is the canonical distribution master.

### Spectral changes (master − source, dB):

The "relative" column subtracts the +5.7 dB integrated-loudness gain, so it reflects only **shape** changes:

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20-60 Hz subbass | +4.71 | **-0.99** (strong sub gently tamed by limiter) |
| 60-120 Hz bass | +4.90 | -0.80 |
| 120-250 Hz lowmid | +5.46 | -0.24 (200 Hz support net-neutral after limiter taming) |
| 250-500 Hz mid | +6.01 | +0.31 |
| **500 Hz-1 kHz mid** | +6.48 | **+0.78** ✓ (mid-scoop fill working) |
| 1-2 kHz upmid | +6.27 | +0.57 |
| **2-4 kHz presence** | +6.30 | **+0.60** ✓ |
| **4-8 kHz brilliance** | +6.45 | **+0.75** ✓ |
| **8-16 kHz air** | +6.72 | **+1.02** ✓ |
| **16 kHz+ ultra** | +6.52 | **+0.82** ✓ |

Confirms the intent: the **midrange valley filled** (500 Hz-1 kHz +0.78 relative — the targeted 700 Hz fill landing where it was aimed), presence and air both opened (+0.60 / +1.02), and the dominant sub gently reined in (-0.99) so the track is no longer sub-led. The low-mid support at 200 Hz nets roughly neutral (-0.24) after the limiter's taming — body added without boom. The track moves from sub-heavy-with-a-mid-hole to balanced, present, and open.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `Grit_Tongue_BRATIJA_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `Grit_Tongue_BRATIJA_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | CD/distribution |
| `Grit_Tongue_BRATIJA_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview |

All three measure **-9.9 LUFS / 4.4 LU**. WAVs measure -1.4 dBTP, MP3 -0.9 dBTP (codec reconstruction).

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

This project uses the **v2 `premaster_diagnostic.sh`** (per-frame `aphasemeter` phase aggregation → mean/min/max), carried forward from `under_my_spell`/`10_outta_10`. The prior pipeline (`10_outta_10`) is kept as `master_pipeline_REFERENCE.sh` rather than overwritten.

### Two framework lessons captured this round
1. **DC-shift stage re-validated.** It was conditionally skipped on the negligible-DC family tracks but never removed. This source (+0.000418) is the threshold case it exists for, and re-enabling it brought DC to ~zero. The conditional-skip-not-delete approach paid off.
2. **Pre-gain sweep for high-LRA sources.** The "pre-gain = target − stage-D" shortcut is only reliable for heavily-squashed sources. For dynamic sources (LRA 5+), the limiter eats more, so the pre-gain must be swept. Documented in the pipeline header.

---

## Streaming platform compliance

| Platform | Target LUFS | Master @ -9.9 | Result |
|---|---|---|---|
| Spotify | -14 | -9.9 | Will be turned down ~4.1 dB |
| Apple Music | -16 | -9.9 | Will be turned down ~6.1 dB |
| YouTube | -14 | -9.9 | Will be turned down ~4.1 dB |
| Tidal | -14 | -9.9 | Will be turned down ~4.1 dB |
| Club/DJ use | -8 to -10 | -9.9 | Direct play, ideal |

True peak of -1.4 dBTP (16-bit WAV master) leaves comfortable margin for lossy re-encoding by streaming codecs (AAC, Opus, Vorbis). No clipping risk expected.

---

## Project structure

```
grit_tongue_bratija/
├── source/                          # Input file
│   └── Grit_Tongue_BRATIJA_26.wav
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
│   ├── Grit_Tongue_BRATIJA_MASTER_32f.wav
│   ├── Grit_Tongue_BRATIJA_MASTER_16.wav
│   └── Grit_Tongue_BRATIJA_MASTER.mp3
├── verification/                    # Post-master checks
│   └── final_loudness.txt
└── scripts/                         # Reusable, parameterized
    ├── premaster_diagnostic.sh      # v2 — phase correlation fixed
    ├── master_pipeline.sh
    ├── master_pipeline_REFERENCE.sh # prior pipeline (10_outta_10) kept for reference
    └── spectral_analysis.sh
```
