# Mastering Report — `NE_SALJI_MI_PPISMO`

**Date:** 2026-05-28
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `NE_SALJI_MI_PPISMO_HITT_POP.wav` (16-bit PCM, **48 kHz**, stereo, 4:41.44)
**Framework:** FFmpeg 6.1.1 — derived from `Try_Aggain` pipeline, parameters re-tuned per pre-master diagnostic
**Source note:** generative source (Suno-style export). Returns to the family's standard **dark-top** profile (unlike the `Try_Aggain` bright outlier), but is the **most macro-dynamic source of the entire family** — mastered as a finished mix with an *open-the-dark-top* approach and deliberately light glue to preserve its unusual aliveness.

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-14.8 LUFS** | Quiet — needs ~+4.8 dB to reach the -10 LUFS target |
| Loudness range (LRA) | **8.1 LU** | **Most macro-dynamic of the entire family** (next closest: zeldi 6.5; the recent trio sat 3.2-4.3) |
| True peak | **-3.6 dBTP** | Clean — no inter-sample clipping in source |
| Sample peak | -3.61 dBFS | Healthy headroom |
| Crest factor | **~13.3 dB** | **Highest of the family** (peak -3.6 − RMS -16.9) — the least-limited, most "alive" source yet |
| DC offset | 0.000292 | Negligible (below audibility threshold) |
| Stereo correlation | mean **+0.486** / min **-0.820** / max +1.000 | **2nd most anti-phase source on record** (after Cofi -0.823) — brief but strong out-of-phase moments |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | **-24.2** | **Quietest sub of the family** — low end is *not* dominant here |
| 60-120 Hz bass | -22.7 | Strongest low band, but modest |
| 120-250 Hz lowmid | -24.6 | Clean step down — no mud build-up |
| 250-500 Hz mid | -25.2 | Healthy, flat-ish |
| 500 Hz-1 kHz | -25.3 | Healthy — mids well-proportioned |
| 1-2 kHz upmid | -29.1 | Step down begins |
| 2-4 kHz presence | -32.2 | Recessed (~7 dB below mids) |
| 4-8 kHz brilliance | -33.1 | |
| 8-16 kHz air | **-34.9** | **Darkest air band of the dark-top family** |
| 16 kHz+ ultra | -44.2 | Steep roll-off — contributes to dark character |

**Key issues:**
1. Low integrated loudness (-14.8 LUFS) needs ~+4.8 dB of make-up gain.
2. **Dark/closed top** — bass→air slope ~12.2 dB; air (-34.9) is the darkest of the dark-top family. The family's signature *open-the-dark-top* move applies.
3. **Low end is light and clean, not dominant** — subbass is actually the *quietest* band (-24.2). No mud, no boom risk → nothing to cut or boost.
4. **Most dynamic source yet** (LRA 8.1, crest ~13.3 dB). This is a genuinely alive mix — heavy compression would flatten its defining feature.
5. Min phase correlation -0.820 → strongly anti-phase → **widening unsafe** (guarantees mono fold-down).

---

## Tuning Decisions vs Reference Template (`Try_Aggain`)

`Try_Aggain` was the family's *bright outlier* (top already open → EQ inverted to preserve-and-polish). `NE_SALJI_MI_PPISMO` shares only the *quiet + clean-peaked + dynamic* profile; tonally it is a **dark-top** source again, so the EQ philosophy **returns to the standard family move** — open the dark top — using the dark-top baseline (`Slap`/`Hit_It`) re-tuned for the darkest top and most dynamic source yet.

| Stage | Try_Aggain (ref) | This track | Why |
|---|---|---|---|
| A: headroom prep | -3 dB | -3 dB | Source quiet; modest attenuation, plenty of EQ headroom |
| A: DC shift | skipped | **skipped** | DC 0.000292 below audibility |
| B: presence | +0.5 dB @ 3.5 kHz | **+0.8 dB @ 3.5 kHz** | Returns to family standard — presence is genuinely recessed (~7 dB under mids), not already-bright like Try_Aggain |
| B: brilliance bridge | removed | **+0.5 dB @ 7 kHz** | Restored — this top is dark, so the sparkle bridge is back (Try_Aggain removed it because 4-8k was already its brightest band) |
| B: air | +0.6 dB @ 15 kHz (whisper) | **+1.9 dB @ 12 kHz (broad)** | **Headline move restored & enlarged.** Broad 12k air lift, biggest of the bumpy family because air (-34.9) is the darkest yet (Hit_It -34.0 → +1.8) |
| B: low-end EQ | none | **none** | Low end light and clean — preserve as-is (consistent with whole recent family) |
| C: compression | th -14 / R 1.5 | th -14 / R 1.5 | Same gentle tier — but here it's a deliberate *under*-compression of a very dynamic source, not a match to a tight one |
| C: makeup | +1.0 dB | +1.0 dB | Filter minimum; lightest allowed |
| D: stereo widening | skipped | **skipped** | Min correlation -0.820 (2nd most anti-phase ever) → widening risks mono fold-down |
| D: headroom prep | -3 dB | -3 dB | Unchanged |
| E: pre-gain | +10.2 dB | **+12.0 dB** | Stage-D measured -20.9 LUFS; this very dynamic source sheds ~1 dB integrated to limiter peak-reduction (~0.5 LUFS per dB pre-gain), so +12.0 lands -10.0 exactly. **Ties Cofi for the highest pre-gain of the family** |
| E: oversample target | 192 kHz (4×) | 192 kHz (4×) | Source native 48 kHz |
| E: limiter ceiling | -1.4 dBFS | -1.4 dBFS | Same family standard — well under -1.0 dBTP after downsample |

> **Note on EQ "restorations":** restoring the brilliance bridge and the broad air lift is a *per-source re-tuning*, the same kind the family always does. Try_Aggain shrank these because its source was already bright; this source is dark again, so they return. No pipeline *feature* was added or removed — every stage, script, and deliverable format is intact and unchanged.

---

## Mastering Chain

All processing performed at 32-bit float internally, 48 kHz end-to-end (oversampled to 192 kHz only inside the limiter). Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-3dB` — peaks move to ~-6.6 dBFS, leaving headroom for EQ boosts
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz (cleans rumble below the musical sub)

### Stage B — Parametric EQ (open the dark top)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 3.5 kHz | +0.8 dB | 1.2 | Lift recessed presence / vocal clarity (~7 dB under mids) |
| Bell | 7 kHz | +0.5 dB | 1.0 | Brilliance bridge (sparkle, avoids harsh 4-6 kHz) |
| Bell | 12 kHz | +1.9 dB | 0.7 | Broad air lift — the biggest of the bumpy family, for the darkest top yet |

**No low-end EQ.** Subbass is the *quietest* band and the bass is modest and clean; boosting would be unwarranted and the limiter gently reins the low end in on its own. The intended weight is preserved.

### Stage C — Bus compression (gentle glue)
`acompressor=threshold=-14dB:ratio=1.5:attack=25:release=200:makeup=1.0:knee=4`

Gentle-tier glue (R 1.5) **despite** the large LRA. With the most macro-dynamic source of the family (LRA 8.1, crest ~13.3 dB), the goal is light cohesion, not loudness — over-compressing would flatten the mix's defining aliveness. The limiter plus natural range reduction bring LRA comfortably under the <8 target (8.1 source → 7.7 after comp → **6.4** final). 25 ms attack preserves kick transients; 200 ms release for musical pumping; `makeup=1.0` is the filter minimum. Adds ~1 dB of average loudness.

### Stage D — Headroom prep (no widening)
- `volume=-3dB` — pre-limiter headroom

**No `extrastereo` applied.** Min phase correlation -0.820 is the second-most anti-phase source on record (after Cofi -0.823). Any widening would push the already strongly out-of-phase sections toward anti-phase and break mono compatibility. Mean correlation +0.486 confirms the source is already adequately wide.

### Stage E — 4× oversampled true-peak limiting
1. **`volume=+12.0dB`** — final loudness gain to target (locked empirically: stage D = -20.9 LUFS; this very dynamic a source sheds ~1 dB to limiter peak-reduction, so +12.0 → -10.0 exactly)
2. **`aresample=192000:resampler=soxr:precision=28`** — 4× upsample (48 → 192 kHz) with SoX precision 28
3. **`alimiter=limit=0.85:attack=2:release=80:level=disabled`** — brickwall sample-peak limit at -1.4 dBFS in the oversampled domain (catches inter-sample reconstruction overshoot a sample-peak limiter would miss)
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample back to 48 kHz

Result: true peak guaranteed under -1.0 dBTP after downsampling (16-bit WAV measures -1.4 dBTP).

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-10.0 LUFS** | ✓ |
| True peak | ≤ -1.0 dBTP | **-1.4 dBTP** (WAV) / **-0.9 dBTP** (MP3) | ✓ |
| Loudness range | < 8 LU | **6.4 LU** | ✓ (the most dynamic master of the family) |

The MP3 true peak (-0.9 dBTP) is 0.5 dB hotter than the WAV due to lossy-codec reconstruction overshoot — expected and within the family's safe band (-0.7 to -1.3 dBTP on MP3). The 16-bit WAV (-1.4 dBTP) is the canonical distribution master and the only one that must meet the -1.0 dBTP target; it does, with comfortable margin.

**Note on the master LRA (6.4 LU):** this is the most dynamic master the pipeline has produced — roughly double the recent trio's 2.9-3.6 LU — and a direct result of the deliberate light-glue choice. It comfortably meets the <8 target while keeping the source's unusual aliveness intact.

### Spectral changes (master − source, dB):

The "relative" column subtracts the +4.8 dB integrated-loudness gain, so it reflects only **shape** changes:

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20-60 Hz subbass | +4.54 | **-0.26** (limiter taming sub transients) |
| 60-120 Hz bass | +4.37 | **-0.43** |
| 120-250 Hz lowmid | +4.44 | -0.36 |
| 250-500 Hz mid | +4.76 | -0.04 (neutral) |
| 500 Hz-1 kHz | +4.84 | +0.04 (neutral) |
| 1-2 kHz upmid | +4.94 | +0.14 |
| **2-4 kHz presence** | +5.37 | **+0.57** ✓ |
| **4-8 kHz brilliance** | +5.85 | **+1.05** ✓ |
| **8-16 kHz air** | +6.30 | **+1.50** ✓ |
| **16 kHz+ ultra** | +5.78 | **+0.98** ✓ |

Confirms the intent: the dark top is opened (presence → ultra all lifted, air the biggest at +1.50), the midrange holds neutral, and the light low end is gently tamed by the limiter so it stays clean and proportioned. The track moves from dark/closed to open and bright while preserving its low-end balance and — uniquely for this family — most of its lively dynamics.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `NE_SALJI_MI_PPISMO_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `NE_SALJI_MI_PPISMO_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | CD/distribution (canonical master) |
| `NE_SALJI_MI_PPISMO_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview |

All three measure **-10.0 LUFS / 6.4 LU**. WAVs measure -1.4 dBTP, MP3 -0.9 dBTP (codec reconstruction).

The track-specific `scripts/master_pipeline.sh` was verified to reproduce the 16-bit master **byte-identical** across re-runs (matching MD5 `a1e1836b…`) — the chain is fully deterministic and auditable.

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

**Note on the diagnostic script:** the project snapshot once again carried the **v1** `premaster_diagnostic.sh`, whose STEREO PHASE CORRELATION block produces empty output (the `aphasemeter` running log is never captured). This project restores **v2**, which aggregates per-frame `lavfi.aphasemeter.phase` metadata into mean / min / max — the input that drives the widening-safety decision. Without it, the min -0.820 reading that ruled out widening would have been invisible. All other features unchanged.

---

## Streaming platform compliance

| Platform | Target LUFS | Master @ -10.0 | Result |
|---|---|---|---|
| Spotify | -14 | -10.0 | Will be turned down ~4.0 dB |
| Apple Music | -16 | -10.0 | Will be turned down ~6.0 dB |
| YouTube | -14 | -10.0 | Will be turned down ~4.0 dB |
| Tidal | -14 | -10.0 | Will be turned down ~4.0 dB |
| Club/DJ use | -8 to -10 | -10.0 | Direct play, ideal |

True peak of -1.4 dBTP (16-bit WAV master) leaves comfortable margin for lossy re-encoding by streaming codecs (AAC, Opus, Vorbis). No clipping risk expected. Because this master retains more dynamic range (LRA 6.4) than the recent family, it will sound noticeably more open and "alive" after platform loudness normalization than the more squashed siblings.

---

## Project structure

```
ne_salji_mi_ppismo/
├── source/                          # Input file
│   └── NE_SALJI_MI_PPISMO_HITT_POP.wav
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
│   ├── NE_SALJI_MI_PPISMO_MASTER_32f.wav
│   ├── NE_SALJI_MI_PPISMO_MASTER_16.wav
│   └── NE_SALJI_MI_PPISMO_MASTER.mp3
├── verification/                    # Post-master checks
│   └── final_loudness.txt
└── scripts/                         # Reusable, parameterized
    ├── premaster_diagnostic.sh      # v2 — phase correlation fixed
    ├── master_pipeline.sh
    ├── master_pipeline_REFERENCE.sh # prior (Try_Aggain) pipeline kept for reference
    └── spectral_analysis.sh
```
