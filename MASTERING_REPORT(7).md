# Mastering Report — `Phoneless_Hardcore_Pop`

**Date:** 2026-05-30
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Phoneless-_Hardcore_Pop.wav` (16-bit PCM, 48 kHz, stereo, 3:17)
**Target:** -10.0 LUFS integrated, ≤ -1.0 dBTP true peak (all deliverables)

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **-13.0 LUFS** | Conservative — needs ~+3 LU to reach target |
| Loudness range (LRA) | **3.4 LU** | Already tightly controlled → light compression only |
| True peak | **-2.0 dBFS** | Clean — no inter-sample clipping |
| Sample peak | -2.3 dBFS | Healthy headroom |
| Crest factor | ~12.8 dB | Transients well preserved |
| DC offset | +0.000215 | Small, removed in prep |
| Mid energy (RMS) | -15.7 dB | |
| Side energy (RMS) | -26.1 dB | Mid/side gap ~10.4 dB → narrow-ish |
| L/R balance | symmetric (peaks -2.6 / -2.3 dB) | No correction needed |

### Spectral balance (octave bands, RMS dB)

| Band | RMS | Read |
|---|---|---|
| 20-60 Hz subbass | -23.2 | Solid |
| 60-120 Hz bass | **-22.3** | Strongest — full low end |
| 120-250 Hz lowmid | -22.8 | Even, no mud build-up |
| 250-500 Hz mid | -23.3 | |
| 500 Hz-1 kHz | -23.4 | |
| 1-2 kHz upmid | -25.6 | Starts to recede |
| 2-4 kHz presence | **-30.0** | ⚠ Scooped |
| 4-8 kHz brilliance | **-32.1** | ⚠ Weakest band |
| 8-16 kHz air | -30.2 | Slightly stronger than brilliance |
| 16 kHz+ ultra | -37.5 | Roll-off |

**Key issues:** Full, even low end but a progressively **recessed upper-midrange / presence** (2–8 kHz scoop). This is the inverse of a muddy mix — the master needs to **lift presence, brilliance, and air** rather than cut lows. Dynamics are already controlled, so compression stays gentle.

---

## Mastering Chain

All processing performed at 32-bit float internally, native 48 kHz preserved end-to-end. Each stage maintains headroom; no clipping until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-6dB` — creates working headroom
- `dcshift=-0.000215` — removes the measured DC offset
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter at 25 Hz

### Stage B — Parametric EQ (lift the scooped top, anchor the low end)

| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 220 Hz | **-0.8 dB** | 1.2 | Gentle low-mid clarity (prevents boxiness as top is lifted) |
| Bell | 55 Hz | +0.6 dB | 1.2 | Sub/fundamental anchor (genre punch) |
| Bell | 3 kHz | **+2.2 dB** | 1.0 | Presence — main fix for the recessed vocal/lead |
| Bell | 6.5 kHz | **+1.8 dB** | 1.0 | Brilliance/edge — the source's weakest band |
| Bell | 12 kHz | +1.5 dB | 0.7 | Broad air lift (pop sheen) |

### Stage C — Bus compression (glue)
`acompressor=threshold=-18dB:ratio=1.6:attack=25:release=180:makeup=1.0:knee=4`

Light 1.6:1 ratio with a slow 25 ms attack preserves the existing transients (source crest ~12.8 dB, LRA 3.4 — already controlled). 4 dB soft knee, 180 ms release for musical glue.

### Stage D — Stereo enhancement
- `extrastereo=m=1.12` — modest 12% widening
- `volume=-3dB` — headroom prep for the limiter

Source was narrow-ish (mid/side gap ~10.4 dB); widened modestly while keeping it mono-safe.

### Stage E — 4× oversampled true-peak limiting
Two parallel limit passes from the same stereo bus:

1. **`volume=+12.5dB`** — final loudness gain to target (calibrated by sweep, see below)
2. **`aresample=192000:resampler=soxr:precision=28`** — upsample 4× (48 → 192 kHz) with the SoX high-precision resampler
3. **`alimiter=limit=0.85` (WAV) / `limit=0.82` (MP3 source)** — brickwall limit in the oversampled domain (catches inter-sample reconstruction overshoot)
4. **`aresample=48000:resampler=soxr:precision=28`** — downsample back to native

The MP3 deliverable uses a separate, lower-ceiling (0.82) source so its true peak stays ≤ -1.0 dBTP even after lossy re-encoding adds overshoot.

#### Pregain calibration (iterative)

| Pregain | Integrated | True peak |
|---|---|---|
| +9.5 dB | -12.5 LUFS | -1.4 dBFS |
| **+12.5 dB** | **-10.0 LUFS** ✓ | -1.4 dBFS |
| +13.5 dB | -9.5 LUFS | -1.4 dBFS |
| +14.5 dB | -9.1 LUFS | -1.4 dBFS |

Loudness gain into the brickwall is sub-1:1 (the limiter clamps the surplus), so +12.5 dB was needed for the 3 LU lift. The ceiling holds the true peak constant across all pregain values, as designed.

---

## Final Master Metrics

| Metric | Target | Actual (32f/16) | Status |
|---|---|---|---|
| Integrated loudness | -10.0 LUFS | **-10.0 LUFS** | ✓ |
| True peak (WAV) | ≤ -1.0 dBTP | **-1.4 dBTP** | ✓ |
| True peak (MP3) | ≤ -1.0 dBTP | **-1.2 dBTP** | ✓ |
| Loudness range | < 8 LU | 2.8 LU | ✓ |

### Spectral changes (master − source, octave RMS dB)

| Band | Δ |
|---|---|
| 20-60 Hz subbass | +2.6 |
| 60-120 Hz bass | +2.4 |
| 120-250 Hz lowmid | +2.1 *(smallest — low-mid kept in check)* |
| 250-500 Hz mid | +2.4 |
| 500 Hz-1 kHz | +2.7 |
| 1-2 kHz upmid | +3.1 |
| **2-4 kHz presence** | **+4.0** *(scoop corrected)* |
| **4-8 kHz brilliance** | **+4.8** *(weakest band, largest lift)* |
| **8-16 kHz air** | **+4.5** |
| 16 kHz+ ultra | +3.8 |

Every band rises because the master is louder overall, but the lift is concentrated in the previously recessed 2–8 kHz region. The master is brought forward and brightened where the source was scooped, while the low end stays anchored and the low-mids stay controlled.

### Stereo width

| | Mid (RMS) | Side (RMS) | Gap |
|---|---|---|---|
| Source | -15.7 | -26.1 | 10.4 dB |
| Master | -13.1 | -22.6 | 9.6 dB |

Side content rose slightly more than mid (+3.4 vs +2.6) — modestly wider, still mono-compatible.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `Phoneless_Hardcore_Pop_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival, future re-encoding |
| `Phoneless_Hardcore_Pop_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | Distribution |
| `Phoneless_Hardcore_Pop_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming/preview |

All deliverables measure -10.0/-10.1 LUFS, with true peak ≤ -1.2 dBTP.

---

## Reusable script

`scripts/master_pipeline_phoneless.sh` reproduces the entire chain, with the calibrated +12.5 dB pregain locked in as the default:

```bash
bash scripts/master_pipeline_phoneless.sh <source.wav> <output_name> <project_dir>
# Override pregain if recalibrating: PREGAIN_DB=13.0 bash scripts/master_pipeline_phoneless.sh ...
```

Diagnostic and verification artifacts are in `analysis/` (`premaster_diagnostic.txt`, `spectral_change.txt`).

## Streaming platform compliance

| Platform | Target LUFS | Master @ -10.0 | Result |
|---|---|---|---|
| Spotify | -14 | -10.0 | Turned down ~4 dB to -14 |
| Apple Music | -16 | -10.0 | Turned down ~6 dB |
| YouTube | -14 | -10.0 | Turned down ~4 dB |
| Tidal | -14 | -10.0 | Turned down ~4 dB |
| Club/DJ use | -8 to -10 | -10.0 | Direct play, ideal |

With true peak ≤ -1.2 dBTP, no clipping occurs even after lossy re-encoding (AAC/Opus) by streaming services.
