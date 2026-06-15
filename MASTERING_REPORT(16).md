# Mastering Report — `POLJAK_IS_BACK`

**Date:** 2026-05-26
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `POLJAK_IS_BACK_TRACK_BB2026.mp3` (**320 kbps CBR MP3 — LOSSY**, 44.1 kHz, stereo, 3:18.87)
**Working file:** `POLJAK_IS_BACK_decoded_32f.wav` (decoded once to 32-bit float, 44.1 kHz)
**Framework:** FFmpeg 6.1.1 — chain reverts toward the original `zeldi_bumbap` reference (loud + clipping source), re-tuned per pre-master diagnostic

> **Two firsts for this project:**
> 1. **First lossy source.** Every prior track was a WAV. This one arrived as a 320 kbps MP3. It was decoded once to 32-bit float and all processing ran on that PCM working file. See the **Lossy-source handling & caveats** section — it affects what "archival" means here and why the limiter ceiling was lowered.
> 2. **Profile is the inverse of the recent run.** The last several tracks were quiet, over-compressed, clean-peaked and needed loudness + brightening. This source is **already loud, very dynamic, and clipping** — it maps onto the original `zeldi_bumbap` reference, and the job is to **fix the clipping while preserving the dynamics**, not to add loudness.

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-10.2 LUFS** | **Already at the -10 target** — essentially no loudness to add |
| Loudness range (LRA) | **10.2 LU** | **Most dynamic source in the project** (recent run was 2-4 LU) — preserve it |
| True peak / sample peak | **+2.44 dBFS** | ⚠ **Inter-sample clipping baked into the lossy master** (samples exceed full scale) |
| Crest factor | 14.71 dB (5.44 linear) | Highest crest to date — lots of transient life; confirms a *dynamic*, not squashed, source |
| DC offset | **-0.001498** | **Largest DC offset in the project** (~3× prior tracks) → correction applied this time |
| Stereo correlation | mean **0.500** / min **-0.542** / max 1.000 | Wide; **phase unsafe for widening** (see below) |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | -18.3 | Strong |
| 60-120 Hz bass | -17.5 | Strongest band — **bass-led** |
| 120-250 Hz lowmid | -19.3 | Clean step down — no mud build-up |
| 250-500 Hz mid | -21.4 | |
| 500 Hz-1 kHz | -23.6 | Smooth descent |
| 1-2 kHz upmid | -26.8 | |
| 2-4 kHz presence | -29.6 | |
| 4-8 kHz brilliance | -29.7 | Top three bands cluster tightly (~-29 to -30) |
| 8-16 kHz air | -30.2 | Moderately recessed (~12 dB below subbass) |
| 16 kHz+ ultra | -41.2 | Roll-off |

**Key issues:**
1. **Inter-sample clipping (+2.44 dBFS)** is the headline problem — identical in kind to the original `zeldi` reference (+3.7 dBFS). The 32-bit float working file can hold it, but any DAC or fixed-point conversion will clip hard. **Fixing this is the primary objective.**
2. **Already at target loudness (-10.2 LUFS)** — unlike the recent run, no make-up gain is needed. The chain's job is clipping control + light shaping, not loudness.
3. **Unusually wide dynamics (LRA 10.2, crest 14.7)** — the most dynamic source the pipeline has seen. These must be **preserved**, so compression is deliberately restrained (the opposite concern from the over-compressed recent tracks).
4. **Bass-led, strong + clean low end** — no mud build-up, so no low-end EQ; the limiter will tame the hot lows slightly on its own.
5. **Moderately dark top** (~12 dB sub→air) — a modest air lift, not the big Hardcore Pop boost.
6. **DC offset -0.0015** — the largest in the project, crossing into "worth correcting" territory → DC shift applied (prior tracks skipped it below ~0.0005).
7. **Phase unsafe for widening** — see below.

### Phase correlation distribution (widening-safety analysis)

| Measure | Value |
|---|---|
| Mean correlation | +0.500 |
| Frames < 0 (anti-phase) | 1874 / 17130 = **10.9%** |
| Frames < -0.2 | 337 / 17130 = **2.0%** |
| Frames ≥ +0.5 (strong) | 9184 / 17130 = 53.6% |

With **10.9% of frames below zero correlation** (and 2.0% below -0.2), this source is materially more anti-phase than `rodjen_sam_u_getu` (where 2.3% / 0.4% made gentle widening safe). **Widening is skipped** to protect mono fold-down. The source is already wide enough.

---

## Lossy-source handling & caveats

This is the first MP3 source in the project, and it changes a few things relative to the WAV-sourced tracks:

- **Single decode to float.** The MP3 was decoded **once** to a 32-bit float WAV at native 44.1 kHz (`source/POLJAK_IS_BACK_decoded_32f.wav`). All analysis and every processing stage runs on that PCM file, so the lossy codec is never re-decoded mid-chain. The original MP3 is retained in `source/` for provenance.
- **"Archival" is qualified.** The `_MASTER_32f.wav` deliverable is the best possible 32-bit float render *from a lossy source* — it is **not** a true lossless archival master in the sense of the WAV-sourced projects. If a lossless source for this track ever becomes available, it should be re-mastered from that.
- **The MP3 deliverable is a second lossy generation.** Re-encoding the master to 320 kbps MP3 means a transcode of a transcode (generation loss). It is still produced per the standing framework, but the **16-bit WAV is the recommended canonical distribution master** here.
- **Limiter ceiling lowered for the second-gen MP3.** At the usual ceiling (0.85 / -1.41 dBFS) the WAV landed -1.3 dBTP and the second-generation MP3 overshot to **-0.9 dBTP**, breaching the -1.0 ceiling. The ceiling was lowered to **0.82 (-1.72 dBFS)** so the WAV lands -1.6 dBTP and the MP3's codec overshoot stays at -1.2 dBTP — comfortably compliant. (Iterative refinement: measured, caught the breach, refined, re-verified.)

---

## Tuning Decisions vs Reference

This track does **not** follow the recent Hardcore Pop template (`Hit_It` / `rodjen`); it reverts toward the **original `zeldi_bumbap`** reference (loud, clipping source). Differences from both are noted:

| Stage | Recent run (rodjen) | zeldi (orig, loud/clip) | **This track** | Why |
|---|---|---|---|---|
| A: headroom prep | -3 dB | -6 dB | **-6 dB** | Clipping +2.44 dBFS source needs the bigger pull-down (like zeldi) |
| A: DC shift | skipped | applied (0.0004) | **applied (0.001498)** | Largest DC offset in project; recentered to 0.000000 |
| A: HPF | 25 Hz | 25 Hz | 25 Hz | Standard subsonic filter |
| B: low-end EQ | +0.8 @ 50 Hz | 200 Hz cut + 80 Hz boost | **none** | Bass-led, strong + clean; no mud, no roll-off to fix |
| B: presence | +0.6 @ 3.5k | +0.6 @ 3.5k | +0.5 @ 3.5k | Light touch |
| B: brilliance | +0.5 @ 7k | — | +0.5 @ 7k | Gentle sparkle bridge |
| B: air | +1.0 @ 12k | +1.5 @ 12k | **+1.2 @ 12k** | Moderate — top ~12 dB dark |
| C: compression | th -14 / R 1.4 | th -16 / R 1.8 | **th -16 / R 1.7** | Between the two: firmer than the gentle tier (LRA 10.2 gives room) but restrained vs zeldi to **preserve** the high crest/LRA |
| C: makeup | +1.0 | +1.5 | **+1.2** | Modest — not chasing loudness; keeps the limiter from being slammed |
| D: widening | 1.05× | 1.10× | **skipped** | 10.9% of frames anti-phase → unsafe |
| E: pre-gain | +10.5 dB | +6.3 dB | **+10.1 dB** | Locked empirically; source already loud but the chain's -9 dB of headroom/prep is recovered here |
| E: oversample | 192 kHz (4×) | 176.4 kHz (4×) | **176.4 kHz (4×)** | Native 44.1 kHz → reverts to the zeldi value, not the 48 kHz run's 192 |
| E: limiter ceiling | 0.85 (-1.41) | 0.85 (-1.41) | **0.82 (-1.72)** | Lowered for the second-gen MP3 true-peak margin |

---

## Mastering Chain

All processing performed at 32-bit float internally, 44.1 kHz end-to-end (oversampled to 176.4 kHz only inside the limiter). Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-6dB` — pulls the clipping +2.44 dBFS peak down to ~-2.8 dBFS, giving EQ headroom
- `dcshift=0.001498` — recenters the -0.0015 DC offset (verified: post-stage DC = 0.000000)
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz

### Stage B — Parametric EQ (light, top-focused)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 3.5 kHz | +0.5 dB | 1.2 | Gentle presence |
| Bell | 7 kHz | +0.5 dB | 1.0 | Brilliance bridge (sparkle) |
| Bell | 12 kHz | +1.2 dB | 0.7 | Modest air lift (top ~12 dB dark) |

**No low-end EQ.** The low end is bass-led, strong and clean with no mud build-up; the limiter gently tames the hot lows on its own (see spectral changes).

### Stage C — Bus compression (gentle-moderate glue, dynamics-preserving)
`acompressor=threshold=-16dB:ratio=1.7:attack=20:release=180:makeup=1.2:knee=4`

Firmer than the recent gentle tier (R 1.4-1.5) because LRA 10.2 gives plenty of macro-dynamic room — but deliberately restrained versus zeldi's 1.8 to **preserve the unusually high crest (14.7 dB) and wide LRA**. The goal is cohesion, **not** loudness (the source is already at -10.2 LUFS). 20 ms attack keeps the transient life; 180 ms release for musical pumping; makeup 1.2 is modest so the limiter is not slammed. Result: LRA preserved at 8.1 going into the limiter.

### Stage D — Headroom prep (no widening)
- `volume=-3dB` — pre-limiter headroom

**No `extrastereo` applied.** With 10.9% of frames below zero correlation (min -0.542), widening would break mono fold-down. The source is already wide.

### Stage E — 4× oversampled true-peak limiting (the headline fix)
1. **`volume=+10.1dB`** — recovers the chain's prep/headroom attenuation to land at target (locked empirically against the -19.1 LUFS stage-D measurement)
2. **`aresample=176400:resampler=soxr:precision=28`** — 4× upsample (44.1 → 176.4 kHz) with SoX precision 28
3. **`alimiter=limit=0.82:attack=2:release=80:level=disabled`** — brickwall sample-peak limit at -1.72 dBFS in the oversampled domain (catches the inter-sample reconstruction overshoot that produced the +2.44 dBFS clip; ceiling lowered from 0.85 for second-gen MP3 margin)
4. **`aresample=44100:resampler=soxr:precision=28`** — downsample back to 44.1 kHz

Result: the source's +2.44 dBFS clipping is resolved — true peak now -1.6 dBTP (WAV), and the dynamics survive (LRA 7.0).

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-10.1 LUFS** | ✓ |
| True peak | ≤ -1.0 dBTP | **-1.6 dBTP** (WAV) / **-1.2 dBTP** (MP3) | ✓ |
| Loudness range | < 8 LU | 7.0 LU | ✓ (intentionally high — dynamics preserved) |
| Clipping | none | resolved (+2.44 dBFS → -1.6 dBTP) | ✓ |

The final LRA of 7.0 LU is **by far the highest in the project** (recent tracks: 1.9-3.3 LU), which is the intended outcome for this unusually dynamic source. The MP3 true peak (-1.2 dBTP) clears the -1.0 ceiling thanks to the lowered limiter ceiling. The 16-bit WAV (-1.6 dBTP) is the canonical distribution master.

### Spectral changes (master − source, dB):

Loudness barely changed (-10.2 → -10.1, only +0.1 dB), so the raw and relative deltas are nearly identical — a clean, direct read of the tonal reshaping:

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20-60 Hz subbass | -1.06 | **-1.16** (limiter taming the hot, clipping low end) |
| 60-120 Hz bass | -0.76 | **-0.86** |
| 120-250 Hz lowmid | -0.10 | -0.20 (near-neutral) |
| 250-500 Hz mid | +0.33 | +0.23 |
| 500 Hz-1 kHz | +0.58 | +0.48 |
| 1-2 kHz upmid | +0.85 | +0.75 |
| **2-4 kHz presence** | +1.13 | **+1.03** ✓ |
| **4-8 kHz brilliance** | +1.59 | **+1.49** ✓ |
| **8-16 kHz air** | +1.96 | **+1.86** ✓ |
| **16 kHz+ ultra** | +2.04 | **+1.94** ✓ |

Confirms the intent: the hot, clipping low end is gently tamed (sub -1.16, bass -0.86), the midrange is lifted slightly, and the moderately dark top is opened smoothly and progressively (presence +1.03 → air +1.86). The track stays loud (it already was), keeps its wide dynamics, loses the clipping, and gains clarity and openness on top.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `POLJAK_IS_BACK_MASTER_32f.wav` | 32-bit float, 44.1 kHz | Best render from lossy source (see caveat — not true-lossless archival) |
| `POLJAK_IS_BACK_MASTER_16.wav` | 16-bit PCM, 44.1 kHz, TPDF dither | **Canonical** CD/distribution master |
| `POLJAK_IS_BACK_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview (**second lossy generation**) |

All three measure **-10.1 LUFS / 7.0 LU**. WAVs measure -1.6 dBTP, MP3 -1.2 dBTP (second-gen codec reconstruction).

---

## Reusable scripts

```bash
# (lossy source only) decode the MP3 once to a 32-bit float working file first:
ffmpeg -i source/<track>.mp3 -c:a pcm_f32le source/<track>_decoded_32f.wav

# Run pre-master diagnostic on the working file (writes a one-page report)
bash scripts/premaster_diagnostic.sh <working.wav> [report.txt]

# Run the full mastering chain (all 3 deliverables + verification)
bash scripts/master_pipeline.sh <working.wav> <output_name> <project_dir>

# Re-run just the spectrum analysis
bash scripts/spectral_analysis.sh <any.wav>
```

`premaster_diagnostic.sh` carries the **v2** working `aphasemeter` phase-correlation aggregation. Two pipeline parameters were reverted to the 44.1 kHz / `zeldi` values for this source — the **oversample target (176.4 kHz, not 192)** and the **-6 dB clipping-source headroom** — and one new behaviour was added: the **limiter ceiling was lowered to 0.82** for second-generation MP3 true-peak margin. Worth keeping as the reference example for **lossy sources** and for **already-loud / clipping** sources going forward.

---

## Streaming platform compliance

| Platform | Target LUFS | Master @ -10.1 | Result |
|---|---|---|---|
| Spotify | -14 | -10.1 | Will be turned down ~3.9 dB |
| Apple Music | -16 | -10.1 | Will be turned down ~5.9 dB |
| YouTube | -14 | -10.1 | Will be turned down ~3.9 dB |
| Tidal | -14 | -10.1 | Will be turned down ~3.9 dB |
| Club/DJ use | -8 to -10 | -10.1 | Direct play, ideal |

True peak of -1.6 dBTP (16-bit WAV master) leaves comfortable margin for lossy re-encoding by streaming codecs (AAC, Opus, Vorbis). With the dynamics preserved (LRA 7.0), platform normalization will turn this down rather than up, so the wide dynamics are retained on playback. No clipping risk expected.

---

## Project structure

```
poljak_is_back/
├── source/                          # Inputs (original lossy + decoded working file)
│   ├── POLJAK_IS_BACK_TRACK_BB2026.mp3      # original 320 kbps MP3 (provenance)
│   └── POLJAK_IS_BACK_decoded_32f.wav       # decoded-once 32-bit float working source
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
│   ├── POLJAK_IS_BACK_MASTER_32f.wav
│   ├── POLJAK_IS_BACK_MASTER_16.wav
│   └── POLJAK_IS_BACK_MASTER.mp3
├── verification/                    # Post-master checks (incl. provenance + clipping fix)
│   └── final_loudness.txt
└── scripts/                         # Reusable, parameterized
    ├── premaster_diagnostic.sh      # v2 — phase correlation working
    ├── master_pipeline.sh           # re-tuned: lossy source, 44.1 kHz, clipping, ceiling 0.82
    └── spectral_analysis.sh
```
