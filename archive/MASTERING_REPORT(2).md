# Mastering Report — `gghoodrap`

**Date:** 2026-06-04
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `gghoodrap.wav` (32-bit float, 44.1 kHz, stereo, 2:25.1)
**House standard:** −10.0 LUFS integrated, ≤ −1.0 dBTP true peak (all deliverables)
**Tooling:** FFmpeg 6.1.1 + libsoxr (precision 28) + libmp3lame. v2 diagnostic reused.

---

## Pre-Master Diagnosis

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **−7.9 LUFS** | **Louder than the −10 target** — needs net attenuation |
| Loudness range (LRA) | 4.4 LU | Moderate for the family |
| **True peak** | **+7.9 dBFS** | **Massively over 0** (Max 2.49 / Min −2.08 linear) |
| Peak count | 2 samples/ch | Transient **overshoot in float**, *not* flat-top clipping |
| RMS level | −10.2 dB | Very high — loud, heavily processed source |
| DC offset | −0.0013 | Largest in the family — removed |
| Stereo correlation | mean +0.58 / min **−0.66** / max +1.00 | Negative min → **widening skipped** |

### Spectral balance (octave bands, RMS dB)

| Band | RMS | Read |
|---|---|---|
| 20–60 Hz subbass | −16.7 | Dominant |
| 60–120 Hz bass | **−16.2** | Strongest band |
| 120–250 Hz lowmid | −17.1 | Strong |
| 250–500 Hz mid | −18.2 | — |
| 500 Hz–1 kHz | −20.3 | — |
| 1–2 kHz upmid | −23.4 | Tilting down |
| 2–4 kHz presence | −26.1 | Recessed |
| 4–8 kHz brilliance | −26.5 | Recessed (dark) |
| 8–16 kHz air | −28.5 | Dark top |
| 16 kHz+ ultra | −42.1 | Roll-off |

**Read:** a very loud, bass-dominant, dark-top hood-rap source with extreme float overshoot. The job is the *opposite* of the recent quiet sources — this one is turned **down** to −10 and its true peak brought firmly under control, while preserving the genre-signature low end and opening the recessed top.

---

## Mastering Chain

All processing at 32-bit float internally. Reproduced by `scripts/master_pipeline_gghoodrap.sh`.

### Stage A — Prep (DEVIATION: deeper headroom)
`volume=-10dB`, `dcshift=0.0` (gated), `highpass=f=25:poles=2`.

The standard −6 dB headroom prep would leave the +7.9 dBFS peaks at +1.9 dBFS — still over 0. Stage A was deepened to **−10 dB** so the peaks land at **−2.2 dBFS** and the EQ/compressor operate on a sane-level signal (compressor thresholds behave as intended rather than over-triggering on an over-0 input). Like the cleaned vocal in earlier sessions, the overshoot is in 32-bit float with only 2 samples at the absolute peak, so this gain reduction recovers the waveform losslessly — no `adeclip` needed. The 25 Hz subsonic HPF removes the −0.0013 DC offset while preserving the sub-bass (verified DC → 0.000000 after Stage A).

### Stage B — Parametric EQ (bass-dominant, dark-top)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 250 Hz | −1.0 dB | 1.1 | Low-mid mud control (avoid congestion when limited) |
| Bell | 3 kHz | +1.5 dB | 1.0 | Presence / vocal intelligibility (recessed) |
| Bell | 6 kHz | +1.5 dB | 1.0 | Brilliance / consonant definition (dark top) |
| Bell | 11 kHz | +1.5 dB | 0.7 | Broad air lift (dark top) |

The dominant sub/bass was **left intact** — it's the genre signature; only the low-mid was trimmed for clarity, and the recessed top lifted.

### Stage C — Bus compression (light glue)
`acompressor=threshold=-18dB:ratio=1.5:attack=25:release=200:makeup=1:knee=4` — light 1.5:1 (LRA 4.4). (`makeup=1` is the linear minimum.)

### Stage D — Stereo stage (WIDENING SKIPPED)
`extrastereo=m=1.00` (min phase −0.66 fails mono safety; stage retained), `volume=-3dB`.

### Stage E — 4× oversampled true-peak limiting (176.4 kHz)
- **E1 (WAV):** `volume=+12.6dB` → `aresample=176400:soxr:precision=28` → `alimiter=limit=0.85:attack=2:release=80` → `aresample=44100:soxr:precision=28`
- **E2 (MP3 source):** identical with `limit=0.84` so the lossy reconstruction stays ≤ −1.0 dBTP independently.

### Calibration log
Stage-D pre-limiter = **−22.0 LUFS** (after the deep −10/−3 headroom staging). Shortcut pre-gain = −10 − (−22.0) = **+12.0**, measured −10.4 (under-shoot confirmed).

| Pre-gain | Integrated | True peak |
|---|---|---|
| +12.0 (shortcut) | −10.4 | −1.4 |
| +12.5 | −10.1 | −1.4 |
| **+12.6 (locked)** | **−10.0** | **−1.4** |
| +12.8 | −9.9 | −1.3 |
| +13.5 | −9.5 | −1.3 |

MP3 ceiling @ +12.6: **0.84 → −1.4 dBTP** (pass, on-target), 0.82 → −1.6, 0.80 → −1.8. Locked **0.84**.

---

## Final Master Metrics

| Metric | Target | 32f WAV | 16-bit WAV | 320k MP3 | Status |
|---|---|---|---|---|---|
| Integrated loudness | −10.0 LUFS | −10.0 | −10.0 | −10.1 | ✓ |
| True peak | ≤ −1.0 dBTP | −1.3 | −1.3 | −1.2 | ✓ |
| Loudness range | tight ok | 3.3 LU | 3.3 LU | 3.2 LU | ✓ |

### Spectral change (master − source, dB)

| Band | Source | Master | Δ |
|---|---|---|---|
| 20–60 Hz subbass | −16.7 | −19.9 | −3.2 |
| 60–120 Hz bass | −16.2 | −18.8 | −2.6 |
| 120–250 Hz lowmid | −17.1 | −19.8 | −2.7 |
| 250–500 Hz mid | −18.2 | −21.0 | −2.8 |
| 500 Hz–1 kHz | −20.3 | −22.8 | −2.5 |
| 1–2 kHz upmid | −23.4 | −25.2 | −1.8 |
| 2–4 kHz presence | −26.1 | −26.7 | −0.6 |
| 4–8 kHz brilliance | −26.5 | −26.3 | +0.2 |
| 8–16 kHz air | −28.5 | −28.3 | +0.2 |
| 16 kHz+ ultra | −42.1 | −42.4 | −0.3 |

Because the source was *louder* than target, all bands drop in absolute terms — but the lows drop ~−2.5 to −3.2 dB while presence/brilliance/air barely move (−0.6/+0.2/+0.2). Net relative effect: the bass dominance is gently tamed and the dark top opened by ~+2.5–3 dB **relative**, while the bass remains the strongest region (genre signature preserved). The 250 Hz trim shows as the largest mid drop.

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `gghoodrap_MASTER_32f.wav` | 32-bit float, 44.1 kHz | Archival |
| `gghoodrap_MASTER_16.wav` | 16-bit PCM, 44.1 kHz, TPDF dither | Distribution |
| `gghoodrap_MASTER.mp3` | 320 kbps CBR, joint stereo | Streaming / DJ |

---

## Determinism verification

Two independent runs produced byte-identical output (MD5):

```
437605a853e3fd387aab558628492a44  gghoodrap_MASTER_32f.wav
d485f8d824c9f47e08e9af24e19d34c4  gghoodrap_MASTER_16.wav
637ae224cb692a2a877faaf2888be217  gghoodrap_MASTER.mp3
```

---

## Streaming platform compliance

| Platform | Target LUFS | Master @ −10.0 | Result |
|---|---|---|---|
| Spotify / YouTube / Tidal | −14 | −10.0 | Turned down ~4 dB |
| Apple Music | −16 | −10.0 | Turned down ~6 dB |
| Club / DJ use | −8 to −10 | −10.0 | Direct play, ideal |

True peak −1.2/−1.3 dBTP leaves margin against lossy re-encode (AAC/Opus). Critically, the source's +7.9 dBFS overs — which would have clipped catastrophically on any fixed-point conversion — are now fully controlled.

---

## Framework notes carried forward

- **First "too loud" source in the family** — every prior source needed large *positive* pre-gain; this one arrived at −7.9 LUFS (hotter than target) and was turned *down* to −10. The same five-stage pipeline handled it; only the framing flips.
- **Stage-A headroom is adaptive** — for a +7.9 dBFS source the standard −6 dB prep was insufficient to get under 0, so Stage A was deepened to −10 dB. Documented as a per-source deviation; the stage itself is unchanged in architecture.
- **Gain-staging beats declipping for float overs, even at +7.9 dBFS** — extreme overshoot with only 2 peak samples is transient, not flat-topped, so reducing gain recovers it losslessly.
- **Genre-signature low end preserved** — the dominant sub/bass was left intact; only mud was trimmed and the dark top lifted, rather than flattening the bass to a generic curve.
- **Shortcut pre-gain under-shot again** (+12.0 → −10.4). Bracketing remains mandatory.
- **Widening-skip held** (min phase −0.66).
- **Housekeeping:** the working container's `/tmp` had filled with prior-session sweep files; cleared mid-session. Worth periodically pruning temp sweep outputs.

---

## Project directory tree

```
gghoodrap_project/
├── MASTERING_REPORT.md
├── source/      (gghoodrap.wav)
├── analysis/    (premaster_diagnostic.txt, master_spectral.txt)
├── intermediate/ (01_prep → 05_limited + mp3src; retained)
├── master/      (gghoodrap_MASTER_32f.wav, _16.wav, .mp3)
├── verification/ (final_loudness.txt, determinism_md5.txt)
└── scripts/     (master_pipeline_gghoodrap.sh, premaster_diagnostic.sh)
```
