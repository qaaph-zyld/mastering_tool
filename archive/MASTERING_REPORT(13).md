# Mastering Report — `Try_Aggain`

**Date:** 2026-05-28
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Try_Aggain_Hardcore_Pop_1.wav` (16-bit PCM, **48 kHz**, stereo, 2:32.32)
**Framework:** FFmpeg 6.1.1 — derived from `Slap` pipeline, parameters re-tuned per pre-master diagnostic
**Source note:** generative source (Suno-style export). Unlike the rest of the hardcore-pop family, this one arrives **already bright, balanced, and dynamic** — mastered as a finished mix with a *preserve-and-polish* philosophy rather than the family's usual *open-the-dark-top* approach.

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-13.6 LUFS** | Quiet — needs ~+3.6 dB to reach the -10 LUFS target |
| Loudness range (LRA) | **4.3 LU** | **Most macro-dynamic of the entire family** (vs 10_outta_10 4.1, Hit_It 3.9, Slap 3.2, UMS 3.5) |
| True peak | **-2.89 dBTP** | Clean — no inter-sample clipping in source |
| Sample peak | -2.89 dBFS | Healthy headroom |
| Crest factor | **~13.2 dB** | **Highest of the family** — the least-limited, most "alive" source so far |
| DC offset | 0.000231 | Negligible (below audibility threshold) |
| Stereo correlation | mean **+0.500** / min **-0.326** / max +0.990 | Widest *average* image of the family; least anti-phase recent source, but still negative |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | -22.6 | **Quietest low end of the family** (others -19 to -21) |
| 60-120 Hz bass | -22.6 | Tied with subbass — **not** bass-dominant |
| 120-250 Hz lowmid | -24.3 | Clean step down — no mud |
| 250-500 Hz mid | -25.1 | |
| 500 Hz-1 kHz | -26.1 | |
| 1-2 kHz upmid | -28.4 | |
| 2-4 kHz presence | -29.0 | |
| 4-8 kHz brilliance | **-28.8** | **Brighter than presence** — unusually forward |
| 8-16 kHz air | **-29.1** | Present and open |
| 16k+ ultra | -38.5 | Only mildly recessed (~16 dB below subbass, vs 22+ on the family) |

**Key issues — and why this track is the family outlier:**
1. Low integrated loudness (-13.6 LUFS) needs ~+3.6 dB of make-up gain. **This is the real job** on this track; almost everything else is already in good shape.
2. **Top is already open.** The bass→air slope is only **~6.5 dB** here, versus **11.7-14.3 dB** across every prior family member. Brilliance (-28.8) even sits *above* presence (-29.0). The family's signature **+1.5-1.8 dB air lift would over-brighten** this source into harshness/sibilance.
3. **Low end is well-proportioned, not dominant.** Sub/bass tied at -22.6 (the quietest lows of the family), descending cleanly. No mud, no boom risk — nothing to cut or boost.
4. **Most dynamic source yet** (LRA 4.3, crest ~13.2 dB). Plenty of macro-dynamic room; heavy compression would needlessly flatten a lively mix.
5. Min phase correlation -0.326 → still negative → **widening unsafe** by family policy (guarantees mono fold-down).

---

## Tuning Decisions vs Reference Template (`Slap`)

`Slap` (and the whole family before it) was tuned for a quiet, clean-peaked, **bass-dominant, dark-top** source whose headline move was a broad air lift. `Try_Aggain` shares only the *quiet + clean-peaked* profile; in tonal balance and dynamics it is the **inverse**. The EQ philosophy therefore flips from *open* to *preserve & polish*:

| Stage | Slap (ref) | This track | Why |
|---|---|---|---|
| A: headroom prep | -3 dB | -3 dB | Source quiet; modest attenuation, plenty of EQ headroom |
| A: DC shift | skipped | **skipped** | DC 0.000231 below audibility |
| B: presence | +0.8 dB @ 3.5 kHz | **+0.5 dB @ 3.5 kHz** | Top doesn't need help; only a light clarity touch |
| B: brilliance bridge | +0.5 dB @ 7 kHz | **removed** | 4-8k (-28.8) is already the *brightest* top region — lifting risks harshness |
| B: air | +1.6 dB @ 12 kHz | **+0.6 dB @ 15 kHz** | **Headline inversion.** Top already open → a whisper of sheen on the *only* recessed band (16k+), not a broad 8-16k lift |
| B: low-end EQ | none | **none** | Lows clean and well-proportioned — preserve as-is |
| C: compression | th -14 / R 1.4 | **th -14 / R 1.5** | LRA 4.3 (most dynamic) → R 1.5 adds light cohesion to the most dynamic source while keeping the ~13 dB crest |
| C: makeup | +1.0 dB | +1.0 dB | Filter minimum; lightest allowed |
| D: stereo widening | skipped | **skipped** | Min correlation -0.326 → still negative → widening risks mono fold-down |
| D: headroom prep | -3 dB | -3 dB | Unchanged |
| E: pre-gain | +9.8 dB | **+10.2 dB** | Stage-D measured -19.8 LUFS; this dynamic a source loses ~0.3 dB integrated to limiter peak-reduction, so +9.8 landed -10.3 and **+10.2 lands -10.0 exactly** |
| E: oversample target | 192 kHz (4×) | 192 kHz (4×) | Source native 48 kHz |
| E: limiter ceiling | -1.4 dBFS | -1.4 dBFS | Same family standard — well under -1.0 dBTP after downsample |

> **Note on EQ "removals":** skipping the brilliance bridge and shrinking the air lift are **per-source re-tunings**, the same kind the family has always done (e.g. zeldi used 4 bands with low-end EQ; later tracks dropped low-end EQ entirely). No pipeline *feature* was removed — every stage, script, and deliverable format is intact. The chain still has presence, brilliance, and air EQ available; this source's diagnostic simply called for a near-flat top-end treatment.

---

## Mastering Chain

All processing performed at 32-bit float internally, 48 kHz end-to-end (oversampled to 192 kHz only inside the limiter). Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-3dB` — peaks move to ~-5.9 dBFS, leaving headroom for EQ
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz (cleans rumble below the musical sub)

### Stage B — Parametric EQ (preserve & polish)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 3.5 kHz | +0.5 dB | 1.2 | Light presence / vocal clarity (half the family's usual lift) |
| Bell | 15 kHz | +0.6 dB | 0.7 | Whisper of ultra-air sheen on the only recessed top band (16k+) |

**No 7 kHz brilliance bridge** (4-8k is already the brightest top region) and **no low-end EQ** (sub/bass/lowmid are clean and well-proportioned). The intent is to keep the source's already-good tonal balance and add only a subtle gloss.

### Stage C — Bus compression (gentle glue)
`acompressor=threshold=-14dB:ratio=1.5:attack=25:release=200:makeup=1.0:knee=4`

Gentle-tier glue. The source LRA is 4.3 LU (the most macro-dynamic of the family) and crest ~13.2 dB (the least-limited), so the goal is light cohesion, not loudness. R 1.5 (a touch firmer than `Slap`'s 1.4) suits the extra dynamic room while preserving the lively crest. 25 ms attack preserves kick transients; 200 ms release for musical pumping; `makeup=1.0` is the filter minimum. Adds ~1 dB of average loudness.

### Stage D — Headroom prep (no widening)
- `volume=-3dB` — pre-limiter headroom

**No `extrastereo` applied.** Min phase correlation -0.326 is the least anti-phase of the recent family, but it is still negative — brief out-of-phase moments exist. Consistent family policy keeps widening off to guarantee mono fold-down. The source is already the widest on average (mean +0.500).

### Stage E — 4× oversampled true-peak limiting
1. **`volume=+10.2dB`** — final loudness gain to target (locked empirically: stage D = -19.8 LUFS; +9.8 → -10.3 because this dynamic a source sheds ~0.3 dB to peak reduction; **+10.2 → -10.0 exactly**)
2. **`aresample=192000:resampler=soxr:precision=28`** — 4× upsample (48 → 192 kHz) with SoX precision 28
3. **`alimiter=limit=0.85:attack=2:release=80:level=disabled`** — brickwall sample-peak limit at -1.4 dBFS in the oversampled domain (catches inter-sample reconstruction overshoot a sample-peak limiter would miss)
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample back to 48 kHz

Result: true peak guaranteed under -1.0 dBTP after downsampling (16-bit WAV measures -1.4 dBTP).

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-10.0 LUFS** | ✓ |
| True peak | ≤ -1.0 dBTP | **-1.4 dBTP** (WAV) / **-0.7 dBTP** (MP3) | ✓ WAV / safe MP3 |
| Loudness range | < 8 LU | 3.6 LU | ✓ |

The MP3 true peak (-0.7 dBTP) is 0.7 dB hotter than the WAV due to lossy-codec reconstruction overshoot — the hottest MP3 of the family to date (the family has ranged -0.7 to -1.3 dBTP on MP3). It is still safely below 0 dBFS, so **no clipping occurs**. The 16-bit WAV (-1.4 dBTP) is the canonical distribution master and the only one that must meet the -1.0 dBTP target; it does, with comfortable margin.

### Spectral changes (master − source, dB):

The "relative" column subtracts the +3.6 dB integrated-loudness gain, so it reflects only **shape** changes:

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20-60 Hz subbass | +3.13 | **-0.47** (limiter taming sub transients) |
| 60-120 Hz bass | +3.24 | **-0.36** |
| 120-250 Hz lowmid | +3.36 | -0.24 |
| 250-500 Hz mid | +3.60 | 0.00 (neutral) |
| 500 Hz-1 kHz | +3.70 | +0.10 |
| 1-2 kHz upmid | +3.75 | +0.15 |
| 2-4 kHz presence | +3.86 | +0.26 |
| 4-8 kHz brilliance | +3.81 | +0.21 |
| 8-16 kHz air | +3.82 | +0.22 |
| 16k+ ultra | +3.86 | +0.27 |

Confirms the *preserve-and-polish* intent. The low end is gently tamed by the limiter (-0.47 / -0.36 / -0.24), the midrange holds neutral, and the top end lifts only **+0.2 to +0.27** — a fraction of the family's usual top-end move (UMS air +1.39, 10_outta_10 air +1.46). The master keeps the source's already-good, naturally bright balance instead of re-shaping it: a clean level lift with a subtle, even gloss and a lightly controlled low end.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `Try_Aggain_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `Try_Aggain_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | CD/distribution (canonical master) |
| `Try_Aggain_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview |

All three measure **-10.0 LUFS / 3.6 LU**. WAVs measure -1.4 dBTP, MP3 -0.7 dBTP (codec reconstruction).

The track-specific `scripts/master_pipeline.sh` was verified to reproduce the 16-bit master **byte-identical** (matching MD5) from the source — the chain is fully deterministic and auditable.

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

**Note on the diagnostic script:** the project snapshot again carried the **v1** `premaster_diagnostic.sh`, whose STEREO PHASE CORRELATION block produces empty output (the `aphasemeter` running log is never captured). This project restores **v2**, which aggregates per-frame `lavfi.aphasemeter.phase` metadata into mean / min / max — the input that drives the widening-safety decision. Without it, the min -0.326 reading that confirmed widening should stay off would have been invisible. All other features unchanged.

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
try_aggain/
├── source/                          # Input file
│   └── Try_Aggain_Hardcore_Pop_1.wav
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
│   ├── Try_Aggain_MASTER_32f.wav
│   ├── Try_Aggain_MASTER_16.wav
│   └── Try_Aggain_MASTER.mp3
├── verification/                    # Post-master checks
│   └── final_loudness.txt
└── scripts/                         # Reusable, parameterized
    ├── premaster_diagnostic.sh      # v2 — phase correlation fixed
    ├── master_pipeline.sh
    ├── master_pipeline_REFERENCE.sh # prior (Slap) pipeline kept for reference
    └── spectral_analysis.sh
```
