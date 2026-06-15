# Mastering Report — `Real_Love_x_Posh_Princess`

**Date:** 2026-05-29
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Real_Love_Hardcore_Pop_1_x_My_Posh_Princess_Hardcore_Pop_2__Mashup_.wav` (16-bit PCM, **48 kHz**, stereo, 4:34.36)
**Framework:** FFmpeg 6.1.1 — derived from `NE_SALJI_MI_PPISMO` pipeline, parameters re-tuned per pre-master diagnostic
**Source note:** generative mashup (Suno-style export). Like `Try_Aggain`, it arrives **already bright, balanced, and dynamic** — mastered with a *preserve-and-polish* philosophy rather than the family's usual *open-the-dark-top* approach. It is the **second bright-top outlier** of the family, and the most extreme on several axes (see below).

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-16.3 LUFS** | **Quietest source of the entire family** (prev. quietest: Cofi -15.1) — needs ~+6.3 dB to reach the -10 LUFS target |
| Loudness range (LRA) | **3.4 LU** | 2nd tightest of the family (after Slap 3.2) — little macro-dynamic room to recover |
| True peak | **-4.1 dBTP** | Clean — no inter-sample clipping in source (cleanest-peaked of the family) |
| Sample peak | -4.07 dBFS | Healthy headroom |
| Crest factor | **~15.6 dB** | **Highest of the family** (prev. high NE_SALJI ~13.3) — the most "alive"/punchy, least-limited source to date |
| DC offset | -0.000093 | Negligible (below audibility threshold) |
| Stereo correlation | mean **+0.784** / min **-0.196** / max +1.000 | **Most mono-compatible on average** and the **least anti-phase source ever recorded** (prev. least: Try_Aggain -0.326) |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | -27.2 | Modest, clean |
| 60-120 Hz bass | **-26.0** | Strongest low band — fundamental |
| 120-250 Hz lowmid | -28.7 | Clean step down — no mud |
| 250-500 Hz mid | -31.8 | **Most recessed region begins** |
| 500 Hz-1 kHz | -31.6 | Scooped |
| 1-2 kHz upmid | -31.6 | Scooped |
| 2-4 kHz presence | -31.6 | Scooped — flat across the whole 250 Hz-4 kHz center |
| 4-8 kHz brilliance | **-29.4** | **Bright** — sits above the mids |
| 8-16 kHz air | **-28.7** | **Brightest top band** — nearly as strong as the bass |
| 16k+ ultra | -39.0 | Only steeply recessed top band (roll-off) |

**Key issues — and why this track is the second family outlier:**
1. **Loudness is the real job.** At -16.3 LUFS this is the quietest source the project has handled; it needs the largest make-up gain to date. Almost everything else is already in good shape.
2. **Top is already open — even more so than `Try_Aggain`.** The bass→air slope is only **~2.7 dB** here, versus 6.5 dB on `Try_Aggain` and 11.7-14.3 dB across every dark-top family member. Brilliance (-29.4) and air (-28.7) sit *above* the entire midrange. The family's signature **+1.5-1.9 dB air lift would over-brighten** this source into harshness/sibilance.
3. **Scooped midrange.** The 250 Hz-4 kHz center is flat and recessed (~-31.6), ~3-5 dB below both the bass and the bright top. This — not the top — is the one region that benefits from a gentle lift (presence / vocal clarity).
4. **Low end modest, clean, well-proportioned.** Bass is the strongest low band (-26.0) descending cleanly; no mud, no boom risk — nothing to cut or boost.
5. **Most dynamic source yet** (crest ~15.6 dB) on a tight LRA (3.4) — punchy transients on a consistent level. Heavy compression would flatten the defining punch.
6. Min phase correlation -0.196 → still negative → **widening unsafe** by consistent family policy (guarantees mono fold-down), though it is the closest any source has come to qualifying.

---

## Tuning Decisions vs Reference Template (`NE_SALJI_MI_PPISMO`)

`NE_SALJI_MI_PPISMO` was a **dark-top** source whose headline move was the family's biggest air lift (+1.9 dB @ 12 kHz). `Real_Love_x_Posh_Princess` shares only the *quiet + clean-peaked + dynamic* profile; in tonal balance it is the **inverse** (bright top, scooped mid). The EQ philosophy therefore flips from *open* to *preserve & polish* — the same inversion first used on `Try_Aggain`, here taken a step further because the top is even more open.

| Stage | NE_SALJI (ref) | This track | Why |
|---|---|---|---|
| A: headroom prep | -3 dB | -3 dB | Source quiet; modest attenuation, plenty of EQ headroom |
| A: DC shift | skipped | **skipped** | DC -0.000093 below audibility |
| B: presence | +0.8 dB @ 3.5 kHz | **+0.7 dB @ 3.0 kHz** | Centered a touch lower with a broader Q (1.0) to fill the *whole* scooped 1-4 kHz center, not a dark-top fix |
| B: brilliance bridge | +0.5 dB @ 7 kHz | **removed** | 4-8k (-29.4) is already one of the brightest bands — lifting risks harshness |
| B: air | +1.9 dB @ 12 kHz | **+0.5 dB @ 16 kHz** | **Headline inversion.** Top already open → a whisper of sheen on the *only* recessed top band (16k+), tight Q to avoid bloating the bright 8-16k — not a broad lift |
| B: low-end EQ | none | **none** | Lows modest, clean and well-proportioned — preserve as-is |
| C: compression | th -14 / R 1.5 | **th -14 / R 1.4** | LRA 3.4 (2nd tightest) + crest ~15.6 (highest) → gentlest tier; preserve the punch |
| C: makeup | +1.0 dB | +1.0 dB | Filter minimum; lightest allowed |
| D: stereo widening | skipped | **skipped** | Min correlation -0.196 → still negative → family mono-safety policy |
| D: headroom prep | -3 dB | -3 dB | Unchanged |
| E: pre-gain | +12.0 dB | **+12.5 dB** | Quietest source ever → **highest pre-gain of the family**. Stage-D measured -22.1 LUFS; this high-crest source sheds ~0.7 dB to limiter peak-reduction, so +12.5 lands -10.0 exactly |
| E: oversample target | 192 kHz (4×) | 192 kHz (4×) | Source native 48 kHz |
| E: limiter ceiling | -1.4 dBFS | -1.4 dBFS | Same family standard — well under -1.0 dBTP after downsample |

> **Note on EQ "removals":** dropping the 7 kHz brilliance bridge and shrinking the air move to a 16 kHz whisper are **per-source re-tunings**, the same kind the family has always done (`Try_Aggain` did the identical inversion; earlier tracks dropped low-end EQ). No pipeline *feature* was removed — every stage, script, and deliverable format is intact. The chain still has presence, brilliance, and air EQ available; this source's diagnostic simply called for a near-flat, scoop-aware top-end treatment.

---

## Mastering Chain

All processing performed at 32-bit float internally, 48 kHz end-to-end (oversampled to 192 kHz only inside the limiter). Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-3dB` — peaks move to ~-7.1 dBFS, leaving headroom for EQ
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz (cleans rumble below the musical sub)

### Stage B — Parametric EQ (preserve & polish, scoop-aware)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 3.0 kHz | +0.7 dB | 1.0 | Gentle fill of the scooped presence/upper-mid center (vocal clarity) |
| Bell | 16 kHz | +0.5 dB | 0.9 | Whisper of ultra-air sheen on the only recessed top band (16k+) |

**No 7 kHz brilliance bridge** (4-8k is already bright) and **no low-end EQ** (lows clean and well-proportioned). The intent is to keep the source's already-good, naturally bright balance and add only a subtle gloss while nudging the recessed center forward.

### Stage C — Bus compression (gentlest glue tier)
`acompressor=threshold=-14dB:ratio=1.4:attack=25:release=200:makeup=1.0:knee=4`

Gentlest tier (R 1.4, matching `Slap` / `Under_My_Spell`). The source LRA is only 3.4 LU but the crest is ~15.6 dB — the most punchy/alive source the project has seen — so the goal is light cohesion, not loudness; the limiter does the loudness work. 25 ms attack preserves kick transients; 200 ms release for musical pumping; `makeup=1.0` is the filter minimum. Adds ~1 dB of average loudness.

### Stage D — Headroom prep (no widening)
- `volume=-3dB` — pre-limiter headroom

**No `extrastereo` applied.** Min phase correlation -0.196 is the least anti-phase of the entire family, but it is still negative — brief out-of-phase moments exist. Consistent family policy keeps widening off to guarantee mono fold-down. The source is also the widest on average (mean +0.784), so it needs no help.

### Stage E — 4× oversampled true-peak limiting
1. **`volume=+12.5dB`** — final loudness gain to target (locked empirically: stage D = -22.1 LUFS; this high-crest source sheds ~0.7 dB to limiter peak-reduction, so **+12.5 → -10.0 exactly**). The highest pre-gain of the family.
2. **`aresample=192000:resampler=soxr:precision=28`** — 4× upsample (48 → 192 kHz) with SoX precision 28
3. **`alimiter=limit=0.85:attack=2:release=80:level=disabled`** — brickwall sample-peak limit at -1.4 dBFS in the oversampled domain (catches inter-sample reconstruction overshoot a sample-peak limiter would miss)
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample back to 48 kHz

Result: true peak guaranteed under -1.0 dBTP after downsampling (16-bit WAV measures -1.4 dBTP).

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-10.0 LUFS** | ✓ |
| True peak | ≤ -1.0 dBTP | **-1.4 dBTP** (WAV) / **-1.0 dBTP** (MP3) | ✓ |
| Loudness range | < 8 LU | 3.1 LU | ✓ |

The MP3 true peak (-1.0 dBTP) is 0.4 dB hotter than the WAV due to lossy-codec reconstruction overshoot — sitting exactly at the safe ceiling (the family has ranged -0.7 to -1.3 dBTP on MP3). It is still at/below 0 dBFS, so **no clipping occurs**. The 16-bit WAV (-1.4 dBTP) is the canonical distribution master and the only one that must meet the -1.0 dBTP target; it does, with comfortable margin.

### Spectral changes (master − source, dB):

The "relative" column subtracts the +6.3 dB integrated-loudness gain, so it reflects only **shape** changes:

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20-60 Hz subbass | +5.98 | **-0.32** (limiter taming sub transients) |
| 60-120 Hz bass | +5.97 | **-0.33** |
| 120-250 Hz lowmid | +6.04 | -0.26 |
| 250-500 Hz mid | +6.24 | -0.06 (neutral) |
| 500 Hz-1 kHz | +6.35 | +0.05 (neutral) |
| **1-2 kHz upmid** | +6.47 | **+0.17** (scoop fill) |
| **2-4 kHz presence** | +6.61 | **+0.31** ✓ (scoop fill — the headline move) |
| 4-8 kHz brilliance | +6.36 | +0.06 (held flat) |
| 8-16 kHz air | +6.29 | -0.01 (held flat) |
| 16k+ ultra | +6.36 | +0.06 (whisper of sheen) |

Confirms the *preserve-and-polish* intent. The **scooped center (1-4 kHz) is gently filled** (+0.17 to +0.31) — the one tonal correction this source needed — while the **already-bright brilliance and air are held essentially flat** (+0.06 / -0.01), avoiding the over-brightening the family's standard air lift would have caused. The low end is lightly tamed by the limiter (-0.26 to -0.33). The master keeps the source's naturally bright, dynamic character and simply raises it to a competitive level with the recessed midrange nudged forward.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `Real_Love_x_Posh_Princess_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `Real_Love_x_Posh_Princess_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | CD/distribution (canonical master) |
| `Real_Love_x_Posh_Princess_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview |

All three measure **-10.0 LUFS / 3.1 LU**. WAVs measure -1.4 dBTP, MP3 -1.0 dBTP (codec reconstruction).

The track-specific `scripts/master_pipeline.sh` was verified to reproduce the 16-bit master **byte-identical** (matching MD5 `b9eb68153d060b83585a1b71b908f218`) across two independent runs — the chain is fully deterministic and auditable.

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

**Note on the diagnostic script:** the project snapshot again carried the **v1** `premaster_diagnostic.sh`, whose STEREO PHASE CORRELATION block produces empty output (the `aphasemeter` running log is never captured). This project restores **v2**, which aggregates per-frame `lavfi.aphasemeter.phase` metadata into mean / min / max — the input that drives the widening-safety decision. Without it, the min -0.196 reading (the closest-yet widening candidate) would have been invisible. All other features unchanged.

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

## Where this track sits in the family (record-setting source)

| Axis | This track | Previous extreme |
|---|---|---|
| Quietest source | **-16.3 LUFS** | Cofi -15.1 |
| Highest crest (most dynamic/punchy) | **~15.6 dB** | NE_SALJI ~13.3 |
| Least anti-phase (closest widening candidate) | **min -0.196** | Try_Aggain -0.326 |
| Highest make-up pre-gain | **+12.5 dB** | NE_SALJI / Cofi +12.0 |
| Most open top (2nd bright outlier) | **bass→air ~2.7 dB** | Try_Aggain ~6.5 dB |

---

## Project structure

```
real_love_x_posh_princess/
├── source/                          # Input file
│   └── Real_Love_x_Posh_Princess_Mashup.wav
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
│   ├── Real_Love_x_Posh_Princess_MASTER_32f.wav
│   ├── Real_Love_x_Posh_Princess_MASTER_16.wav
│   └── Real_Love_x_Posh_Princess_MASTER.mp3
├── verification/                    # Post-master checks
│   └── final_loudness.txt
└── scripts/                         # Reusable, parameterized
    ├── premaster_diagnostic.sh      # v2 — phase correlation fixed
    ├── master_pipeline.sh
    ├── master_pipeline_REFERENCE.sh # prior (zeldi) pipeline kept for reference
    └── spectral_analysis.sh
```
