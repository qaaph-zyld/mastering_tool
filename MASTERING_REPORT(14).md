# Mastering Report — `Slap`

**Date:** 2026-05-28
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Slap_-_Hardcore_Pop.wav` (16-bit PCM, **48 kHz**, stereo, 3:07.28)
**Framework:** FFmpeg 6.1.1 — derived from `10_outta_10` pipeline, parameters re-tuned per pre-master diagnostic
**Source note:** generative source (Suno-style export); already loud-ish, compressed, and dark — handled as a finished mix, mastered conservatively.

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-13.5 LUFS** | Quiet — needs ~+3.5 dB to reach commercial target |
| Loudness range (LRA) | **3.2 LU** | **Tightest of the entire family** (vs UMS 3.5, Hit_It 3.9, 10_outta_10 4.1) — minimal dynamics to recover |
| True peak | **-3.1 dBTP** | Clean — no inter-sample clipping in source |
| Sample peak | -3.13 dBFS | Healthy headroom |
| Crest factor | ~11.8 dB | Confirms an already heavily-limited source |
| DC offset | 0.000229 | Negligible (below audibility threshold) |
| Stereo correlation | mean **0.656** / min **-0.356** / max 0.997 | Wide; **least anti-phase recent source**, but min still negative |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | -20.3 | Very strong |
| 60-120 Hz bass | **-20.0** | Strongest band — fundamental |
| 120-250 Hz lowmid | -22.4 | Full — only ~2.4 dB under bass |
| 250-500 Hz mid | -26.6 | Clean step down |
| 500 Hz-1 kHz | -27.0 | |
| 1-2 kHz upmid | -28.3 | |
| 2-4 kHz presence | -29.9 | No discrete scoop — smooth descending slope |
| 4-8 kHz brilliance | -31.3 | |
| 8-16 kHz air | -32.9 | Recessed (~12.9 dB below bass) |
| 16 kHz+ ultra | -42.8 | Steep roll-off — contributes to dark character |

**Key issues:**
1. Low integrated loudness (-13.5 LUFS) needs ~+3.5 dB of make-up gain.
2. **Bass-dominant, smooth-slope profile** — sub/bass/lowmid sit within ~2.4 dB (-20.3 / -20.0 / -22.4), very strong; everything above drops off smoothly with no presence scoop.
3. **Dark/closed top** — bass→air slope ~12.9 dB; air recessed. Sits between `Under_My_Spell` (11.7 dB slope) and `10_outta_10` (14.0 dB slope).
4. **Tightest dynamics of any track to date** (LRA 3.2, crest ~11.8 dB) — heavy further compression would over-squash.
5. Min phase correlation -0.356 → still negative (brief out-of-phase moments) → **widening kept off** for guaranteed mono fold-down.

---

## Tuning Decisions vs Reference Template (`10_outta_10`)

`10_outta_10` was tuned for a quiet, clean-peaked, bass-dominant, dark-top source. `Slap` shares that family profile but is **the tightest-dynamics track yet (LRA 3.2) and the most mono-safe recent source (min corr -0.356)**. Each stage was re-tuned accordingly:

| Stage | 10_outta_10 (ref) | This track | Why |
|---|---|---|---|
| A: headroom prep | -3 dB | -3 dB | Source quiet; modest attenuation, plenty of EQ headroom |
| A: DC shift | skipped | **skipped** | DC 0.000229 below audibility |
| B: presence | +0.8 dB @ 3.5 kHz | +0.8 dB @ 3.5 kHz | Vocal clarity in a bass-heavy mix; no scoop to fill |
| B: brilliance | +0.5 dB @ 7 kHz | +0.5 dB @ 7 kHz | Brilliance (-31.3) close to ref (-30.9) → same gentle bridge |
| B: air | +1.7 dB @ 12 kHz | **+1.6 dB @ 12 kHz** | Top (-32.9) sits between UMS (-32.0, +1.5) and 10_outta_10 (-33.4, +1.7) → interpolated lift |
| B: low-end EQ | none | **none** | Sub/bass/lowmid already strongest — preserve the intended weight |
| C: compression | th -14 / R 1.5 | **th -14 / R 1.4** | LRA 3.2 is tightest yet → drop to gentlest tier (matches Under_My_Spell at LRA 3.5) |
| C: makeup | +1.0 dB | +1.0 dB | Filter minimum; lightest allowed |
| D: stereo widening | skipped | **skipped** | Min corr -0.356 still negative → keep mono fold-down guarantee |
| D: headroom prep | -3 dB | -3 dB | Unchanged |
| E: pre-gain | +8.9 dB | **+9.8 dB** | Source quieter (-13.5); stage-D measured -19.7 LUFS → +9.8 lands -10.0 exactly |
| E: oversample target | 192 kHz (4×) | 192 kHz (4×) | Source native 48 kHz |
| E: limiter ceiling | -1.4 dBFS | -1.4 dBFS | Same — well under -1.0 dBTP after downsample |

---

## Mastering Chain

All processing performed at 32-bit float internally, 48 kHz end-to-end (oversampled to 192 kHz only inside the limiter). Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-3dB` — peaks move to ~-6.1 dBFS, leaving headroom for EQ boosts
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz (cleans rumble below the musical sub)

### Stage B — Parametric EQ (top-focused)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 3.5 kHz | +0.8 dB | 1.2 | Lift presence / vocal clarity in a bass-heavy mix |
| Bell | 7 kHz | +0.5 dB | 1.0 | Brilliance bridge (sparkle, avoids harsh 4-6 kHz) |
| Bell | 12 kHz | +1.6 dB | 0.7 | Broad air lift — open the dark top |

**No low-end EQ.** Sub, bass, and low-mid are already the three strongest bands and sit within ~2.4 dB of each other. Boosting would worsen the bass dominance and risk a boomy limiter. The intended weight is preserved; the limiter alone gently reins in the low end (see relative deltas below).

### Stage C — Bus compression (gentlest glue)
`acompressor=threshold=-14dB:ratio=1.4:attack=25:release=200:makeup=1.0:knee=4`

Gentlest tier — the source LRA is only 3.2 LU (tightest of the family) and crest ~11.8 dB (already heavily limited), so the goal is cohesion, not loudness. 25 ms attack preserves kick transients (hardcore-pop punch); 200 ms release for musical pumping; `makeup=1.0` is the filter minimum (valid range 1-64). Adds ~1 dB of average loudness.

### Stage D — Headroom prep (no widening)
- `volume=-3dB` — pre-limiter headroom

**No `extrastereo` applied.** Min phase correlation is -0.356 — the least anti-phase of the recent family, but still negative, meaning brief out-of-phase moments exist. Consistent family policy keeps widening off so the master folds down to mono cleanly. The source is already wide enough (mean 0.656).

### Stage E — 4× oversampled true-peak limiting
1. **`volume=+9.8dB`** — final loudness gain to target (locked empirically against the -19.7 LUFS stage-D measurement)
2. **`aresample=192000:resampler=soxr:precision=28`** — 4× upsample (48 → 192 kHz) with SoX precision 28
3. **`alimiter=limit=0.85:attack=2:release=80:level=disabled`** — brickwall sample-peak limit at -1.4 dBFS in the oversampled domain (catches inter-sample reconstruction overshoot a sample-peak limiter would miss)
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample back to 48 kHz

Result: true peak guaranteed under -1.0 dBTP after downsampling.

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-10.0 LUFS** | ✓ |
| True peak | ≤ -1.0 dBTP | **-1.4 dBTP** (WAV) / **-1.1 dBTP** (MP3) | ✓ |
| Loudness range | < 8 LU | 2.9 LU | ✓ |

The MP3 true peak (-1.1 dBTP) is 0.3 dB higher than the WAV due to lossy-codec reconstruction overshoot — expected and comfortably inside the safe band (the family has ranged -0.8 to -1.3 dBTP on MP3). The 16-bit WAV (-1.4 dBTP) is the canonical distribution master.

### Spectral changes (master − source, dB):

The "relative" column subtracts the +3.5 dB integrated-loudness gain, so it reflects only **shape** changes:

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20-60 Hz subbass | +2.91 | **-0.59** (limiter taming sub transients) |
| 60-120 Hz bass | +3.00 | **-0.50** |
| 120-250 Hz lowmid | +3.15 | -0.35 (full low-mid held, lightly tamed) |
| 250-500 Hz mid | +3.37 | -0.13 |
| 500 Hz-1 kHz | +3.47 | -0.03 (neutral) |
| 1-2 kHz upmid | +3.62 | +0.12 (neutral) |
| **2-4 kHz presence** | +4.10 | **+0.60** ✓ |
| **4-8 kHz brilliance** | +4.61 | **+1.11** ✓ |
| **8-16 kHz air** | +4.98 | **+1.48** ✓ |
| **16 kHz+ ultra** | +4.78 | **+1.28** ✓ |

Confirms the intent: top end opened (presence → ultra all lifted), midrange held neutral, and the very strong low end gently tamed by the limiter so it no longer dominates — while the full low-mid (-0.35) is preserved more than sub/bass, keeping the track's weight intact. The track moves from bass-heavy/dark to open and bright without losing low-end body.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `Slap_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `Slap_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | CD/distribution |
| `Slap_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview |

All three measure **-10.0 LUFS / 2.9 LU**. WAVs measure -1.4 dBTP, MP3 -1.1 dBTP (codec reconstruction).

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

**Note on the diagnostic script:** the project snapshot again carried the *v1* `premaster_diagnostic.sh`, whose STEREO PHASE CORRELATION block produces empty output (the `aphasemeter` running log is never captured). This project restores **v2**, which aggregates per-frame `lavfi.aphasemeter.phase` metadata into mean / min / max — the correlation input that drives the widening-safety decision. Without it, the min -0.356 reading would have been invisible. All other features unchanged.

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
slap/
├── source/                          # Input file
│   └── Slap_-_Hardcore_Pop.wav
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
│   ├── Slap_MASTER_32f.wav
│   ├── Slap_MASTER_16.wav
│   └── Slap_MASTER.mp3
├── verification/                    # Post-master checks
│   └── final_loudness.txt
└── scripts/                         # Reusable, parameterized
    ├── premaster_diagnostic.sh      # v2 — phase correlation fixed
    ├── master_pipeline.sh
    ├── master_pipeline_REFERENCE.sh # prior pipeline kept for reference
    └── spectral_analysis.sh
```
