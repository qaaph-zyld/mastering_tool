# Mastering Report — `MONSTAH_demo_1_gg`

**Date:** 2026-06-01
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `MONSTAH_demo_1_gg.mp3` — **MP3 ~193 kbps**, 48 kHz, stereo, 2:47.68 (with embedded cover art)
**Framework:** FFmpeg 6.1.1 — derived from `NE_SALJI_MI_PPISMO` pipeline, parameters re-tuned per pre-master diagnostic
**Source note:** generative source (Suno-style export) delivered as a **lossy MP3** — the first lossy-origin track in the active family. Decoded to 32-bit float before any processing; top-end lift kept deliberately conservative (boosting air also amplifies MP3 high-frequency quantisation artifacts).

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| **Origin format** | **MP3 ~193 kbps** | Lossy — decoded to float WAV first; treated as a finished mix |
| Integrated loudness | **-13.9 LUFS** | Quiet — needs ~+3.9 dB to reach the -10 LUFS target |
| Loudness range (LRA) | **3.2 LU** | Squashed — ties `Slap` as the most-compressed source in the family |
| True peak | **-2.26 dBTP** | Clean — no inter-sample clipping in source |
| Sample peak | -2.26 dBFS | Headroom-safe |
| Crest factor | ~13.4 dB | Confirms a heavily-limited generative source |
| DC offset | 0.000288 | Negligible (below audibility) |
| Stereo correlation | mean **+0.677** / min **-0.609** / max +1.000 | Adequately wide; brief out-of-phase moments → widening unsafe |

### Spectral balance (octave bands, RMS dB):

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | **-21.46** | Strong |
| 60-120 Hz bass | **-21.51** | Essentially equal to sub → **sub-leaning, very even** low end |
| 120-250 Hz lowmid | -23.36 | Clean step down — no mud |
| 250-500 Hz mid | -25.64 | |
| 500 Hz-1 kHz | -26.27 | |
| 1-2 kHz upmid | -27.77 | |
| 2-4 kHz presence | **-29.50** | **Best-placed top in the family's dark cohort** |
| 4-8 kHz brilliance | -31.43 | |
| 8-16 kHz air | **-33.15** | Recessed, but the mildest dark-top in the family |
| 16 kHz+ ultra | -44.63 | Steep roll-off |

**Key observations:**
1. Low loudness (-13.9 LUFS) needs ~+3.9 dB make-up.
2. **Even, sub-leaning low end** — sub and bass within 0.05 dB, descending cleanly. Nothing to cut or boost.
3. **Dark top, but the mildest in the family** — bass→air slope only ~11.6 dB (vs 13.8 on Little_Planet). Air -33.2 sits between `Slap` (-32.9) and `10_outta_10` (-33.4).
4. **Presence is the best-placed of any dark-cohort track** (-29.5) — needs only a light clarity lift, not a fill.
5. Squashed source (LRA 3.2, crest ~13.4 dB) → lightest-tier glue only.
6. Min phase correlation -0.609 → widening unsafe.
7. **Lossy origin** → top-end lift held conservative; air boosts amplify MP3 HF artifacts on a decoded source.

Its closest sibling is **`Slap`** (squashed, dark-but-mild, sub-leaning, air ~-33), with two distinguishing traits: the lossy MP3 origin, and the best presence placement in the dark cohort.

---

## Tuning Decisions vs Reference Template (`NE_SALJI_MI_PPISMO`)

| Stage | NE_SALJI (ref) | This track | Why |
|---|---|---|---|
| **0: decode** | n/a (WAV source) | **MP3 → float WAV** | First lossy-origin track; explicit decode stage added, cover-art stream dropped |
| A: headroom prep | -3 dB | -3 dB | Source quiet; modest attenuation |
| A: DC shift | skipped | **skipped** | DC 0.000288 below audibility |
| B: presence | +0.8 dB @ 3.5 kHz | **+0.7 dB @ 3.5 kHz** | Presence (-29.5) best-placed in the cohort → needs slightly less |
| B: brilliance bridge | +0.5 dB @ 7 kHz | +0.5 dB @ 7 kHz | Brilliance -31.4 → standard bridge |
| B: air | +1.9 dB @ 12 kHz | **+1.6 dB @ 12 kHz** | Air -33.2 → matches `Slap`'s +1.6; held to the low side for the lossy origin |
| B: low-end EQ | none | **none** | Even, sub-leaning, well-proportioned → preserve |
| C: compression | th -14 / R 1.5 | th -14 / R 1.5 | Lightest tier; LRA 3.2 (ties most-squashed) → cohesion only |
| C: makeup | +1.0 dB | +1.0 dB | Filter minimum |
| D: stereo widening | skipped | **skipped** | Min correlation -0.609 → mono-safety fail |
| D: headroom prep | -3 dB | -3 dB | Unchanged |
| E: pre-gain | +12.0 dB | **+11.0 dB** | Locked by bracket sweep (see below) |
| **E2: MP3-path limiter** | -1.94 dBFS ceiling | **-1.94 dBFS ceiling** | Framework standard; doubly important re-encoding a decoded MP3 |
| E: oversample target | 192 kHz (4×) | 192 kHz (4×) | Source native 48 kHz |
| E: WAV limiter ceiling | -1.4 dBFS | -1.4 dBFS | Family standard |

---

## Mastering Chain

All processing performed at 32-bit float internally, 48 kHz end-to-end (oversampled to 192 kHz only inside the limiter).

### Stage 0 — Decode (lossy source)
- `ffmpeg -map 0:a -c:a pcm_f32le` — decode the 193 kbps MP3 to 32-bit float WAV, dropping the embedded cover-art (mjpeg) stream. All subsequent processing is lossless float.

### Stage A — Prep
- `volume=-3dB` — peaks move to ~-5.3 dBFS, leaving headroom for EQ boosts
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz

### Stage B — Parametric EQ (top-focused, conservative for lossy origin)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 3.5 kHz | +0.7 dB | 1.2 | Light presence/clarity lift (presence already well-placed) |
| Bell | 7 kHz | +0.5 dB | 1.0 | Brilliance bridge (sparkle, avoids harsh 4-6 kHz) |
| Bell | 12 kHz | +1.6 dB | 0.7 | Air lift — open the (mild) dark top; matches `Slap`, held to the low side for lossy HF safety |

**No low-end EQ.** Sub and bass are near-identical and descend cleanly; boosting would unbalance an already even low end.

### Stage C — Bus compression (gentle glue)
`acompressor=threshold=-14dB:ratio=1.5:attack=25:release=200:makeup=1.0:knee=4`

Lightest-tier glue. Source LRA is 3.2 LU (ties most-squashed in the family) and crest ~13.4 dB — cohesion only, no loudness. 25 ms attack preserves transients; 200 ms musical release; `makeup=1.0` is the filter minimum.

### Stage D — Headroom prep (no widening)
- `volume=-3dB` — pre-limiter headroom

**No `extrastereo`.** Min phase correlation -0.609 → widening would break mono fold-down. Source already adequately wide (mean +0.677).

### Stage E — 4× oversampled true-peak limiting (WAV path)
1. **`volume=+11.0dB`** — final loudness gain (locked by bracket sweep, below)
2. **`aresample=192000:resampler=soxr:precision=28`** — 4× upsample (48 → 192 kHz)
3. **`alimiter=limit=0.85:...`** — brickwall at -1.4 dBFS in the oversampled domain
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample to 48 kHz

### Stage E2 — Lower-ceiling limiter pass (MP3 path)
A second limiter pass identical to Stage E except the ceiling is **0.80 (-1.94 dBFS)**. `libmp3lame` produces reconstruction peaks independent of the WAV ceiling, so the WAV's -1.4 dBFS cannot guarantee MP3 true-peak compliance. **This matters more here than on any prior track**: re-encoding a *decoded MP3* back to MP3 can compound HF reconstruction overshoot, so the dedicated lower-ceiling MP3 path is essential. The 320 kbps MP3 is encoded from this E2 file, not the WAV master.

---

## Limiter Pre-Gain Calibration Sweep

Stage D measured **-20.2 LUFS**. Counter-intuitively, this heavily-squashed/flat-topped source sheds **~1.0 dB** of integrated loudness to the limiter (vs only ~0.3 dB on the moderately-dynamic Little_Planet) — because near-flat-topped material drives the brickwall into near-constant gain reduction. The naive +10.2 dB undershot to -10.5. Bracketed and extended:

| Pre-gain | Integrated | True peak | Result |
|---|---|---|---|
| +10.0 dB | -10.6 LUFS | -1.4 dBFS | undershoot |
| +10.2 dB | -10.5 LUFS | -1.4 dBFS | undershoot |
| +10.4 dB | -10.4 LUFS | -1.4 dBFS | undershoot |
| +10.6 dB | -10.2 LUFS | -1.4 dBFS | undershoot |
| +10.8 dB | -10.1 LUFS | -1.4 dBFS | close |
| **+11.0 dB** | **-10.0 LUFS** | **-1.4 dBFS** | **selected** ✓ |

`+11.0 dB` selected as the most transient-preserving value that lands the target exactly.

---

## Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-10.0 LUFS** (WAV) / -10.3 (MP3) | ✓ |
| True peak | ≤ -1.0 dBTP | **-1.4 dBTP** (WAV) / **-1.6 dBTP** (MP3) | ✓ both |
| Loudness range | < 8 LU | 2.3 LU | ✓ |

The MP3 measures -10.3 LUFS / -1.6 dBTP — slightly quieter and lower-peaked than the WAV, the expected and intended cost of the E2 -1.94 dBFS ceiling. This is the **most peak-compliant MP3 of the family** (others ranged -0.7 to -1.3 dBTP); the extra margin is deliberate insurance against compounding artifacts on a lossy-origin → lossy-output path. The 16-bit WAV (-1.4 dBTP) is the canonical distribution master.

### Spectral changes (master − source, dB):

The "relative" column subtracts the +3.9 dB integrated-loudness gain, isolating **shape** changes:

| Band | Raw Δ | Relative Δ |
|---|---|---|
| 20-60 Hz subbass | +3.16 | **-0.74** (limiter taming) |
| 60-120 Hz bass | +3.13 | **-0.77** |
| 120-250 Hz lowmid | +3.45 | -0.45 |
| 250-500 Hz mid | +3.80 | -0.10 (neutral) |
| 500 Hz-1 kHz | +3.94 | +0.04 (neutral) |
| 1-2 kHz upmid | +4.07 | +0.17 |
| **2-4 kHz presence** | +4.47 | **+0.57** ✓ |
| **4-8 kHz brilliance** | +5.08 | **+1.18** ✓ |
| **8-16 kHz air** | +5.64 | **+1.74** ✓ |
| **16 kHz+ ultra** | +5.43 | **+1.53** ✓ |

Confirms the intent: top opened (presence → ultra all lifted), midrange neutral, even low end gently tamed by the limiter. The air relative-delta (+1.74) sits a touch above the +1.6 EQ boost — the limiter's broadband lift interacting with the light compression — but stays within family norms and on the conservative side appropriate to a lossy source.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `MONSTAH_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `MONSTAH_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | CD/distribution (canonical master) |
| `MONSTAH_MASTER.mp3` | 320 kbps CBR, joint stereo (from E2 path) | Streaming/preview |

WAVs measure -10.0 LUFS / -1.4 dBTP; MP3 -10.3 LUFS / -1.6 dBTP.

The track-specific `scripts/master_pipeline.sh` reproduces the 16-bit master **byte-identical** (MD5 `4615f7d949f4a0c6cd6c976da4ada1aa`) on a clean re-run from the original MP3 — fully deterministic and auditable.

---

## Reusable scripts

```bash
# Pre-master diagnostic (writes a one-page report)
bash scripts/premaster_diagnostic.sh <source.wav> [report.txt]

# Full mastering chain (decode + all 3 deliverables + verification)
# NOTE: this pipeline takes the MP3 directly and decodes internally
bash scripts/master_pipeline.sh <source.mp3> <output_name> <project_dir>

# Spectrum analysis
bash scripts/spectral_analysis.sh <any.wav>
```

**Diagnostic script status — RESOLVED:** for the first time, the project snapshot shipped the **v2** `premaster_diagnostic.sh` with the working per-frame `lavfi.aphasemeter.phase` aggregation already in place. It ran clean from the snapshot (15,720 frames, min correlation -0.609 captured correctly) with no restoration needed. The long-standing per-session fix appears to have finally been baked into the base template. Worth confirming it persists on the next track before considering the issue permanently closed.

**Lossy-origin handling (new pattern):** this is the first MP3-sourced track in the active family. Two framework adaptations were applied and should carry forward for any future lossy sources: (1) an explicit Stage 0 decode-to-float with cover-art stream removal, and (2) a more conservative top-end EQ to avoid amplifying MP3 HF artifacts. The existing Stage E2 MP3 path already covered the lossy→lossy peak risk.

---

## Streaming platform compliance

| Platform | Target LUFS | Master @ -10.0 | Result |
|---|---|---|---|
| Spotify | -14 | -10.0 | Turned down ~4.0 dB |
| Apple Music | -16 | -10.0 | Turned down ~6.0 dB |
| YouTube | -14 | -10.0 | Turned down ~4.0 dB |
| Tidal | -14 | -10.0 | Turned down ~4.0 dB |
| Club/DJ use | -8 to -10 | -10.0 | Direct play, ideal |

True peak of -1.4 dBTP (16-bit WAV master) leaves comfortable margin for lossy re-encoding by streaming codecs.

---

## Project structure

```
monstah/
├── source/
│   ├── MONSTAH_demo_1_gg.mp3              # original lossy source (provenance)
│   └── MONSTAH_demo_1_gg_decoded.wav     # Stage-0 float decode
├── analysis/
│   ├── full_diagnostic.txt
│   ├── source_spectrum.txt
│   └── master_spectrum.txt
├── intermediate/
│   ├── 01_prep.wav
│   ├── 02_eq.wav
│   ├── 03_comp.wav
│   ├── 04_stereo.wav
│   ├── 05_limited.wav                    # WAV path (-1.4 dBFS)
│   └── 05b_limited_mp3path.wav           # E2 MP3 path (-1.94 dBFS)
├── master/
│   ├── MONSTAH_MASTER_32f.wav
│   ├── MONSTAH_MASTER_16.wav
│   └── MONSTAH_MASTER.mp3
├── verification/
│   └── final_loudness.txt
└── scripts/
    ├── premaster_diagnostic.sh           # v2 (shipped correct in snapshot)
    ├── master_pipeline.sh
    ├── master_pipeline_REFERENCE.sh      # prior (NE_SALJI) pipeline kept for reference
    └── spectral_analysis.sh
```
