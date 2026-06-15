# Mastering Report — `I_ccan_Tell_Hardcore_Pop_2`

**Date:** 2026-06-10
**Engineer:** Claude (open-source pipeline — FFmpeg 6.1.1 + LV2)
**Source:** `I_ccan_Tell_Hardcore_Pop_2.wav` (16-bit PCM, 48 kHz, stereo, 3:31)
**Pipeline:** `master_pipeline_v3.sh` (canonical orchestrator) via per-track wrapper `master_pipeline_ICT2.sh`
**Environment of record:** FFmpeg 6.1.1, lilv-utils 0.24.22 (`lv2apply`), LSP Plugins 1.2.14, Airwindows LV2 ClipOnly2 (built from source), SoX soxr precision 28, libmp3lame 320k CBR
**Profile:** house default (archival) — **−10.0 LUFS / ≤ −1.0 dBTP** (no profile flag passed; byte-for-byte default path)

---

## Pre-Master Diagnosis (v2 diagnostic, measured before any processing)

| Metric | Source | Notes |
|---|---|---|
| Integrated loudness | **−14.1 LUFS** | Quietest HP2 source in the family (ATTSS2 was −13.2) |
| Loudness range (LRA) | 4.2 LU | Compact — far less dynamic than ATTSS2 (7.6) |
| True peak | **−4.4 dBTP** | Clean; large headroom; no inter-sample clipping |
| Sample peak | −4.4 dBFS | |
| Crest factor | 10.7 dB (peak−RMS) | Moderate (ATTSS2 ~14.4) |
| DC offset | **+0.000419** | Above the ~0.0004 family threshold — and the first **positive**-sign offset in the family → DC stage re-enabled, `dcshift=-0.000419` |
| Stereo correlation | mean **+0.735** / min **−0.822** / max +1.000 (9 902 frames) | Worst *minimum* measured in the family → widening SKIP per locked policy. Healthy mean carries mono fold-down (verified below). |

### Spectral balance (octave bands, RMS dB)

| Band | RMS | Read |
|---|---|---|
| 20–60 Hz subbass | −20.4 | Solid |
| 60–120 Hz bass | **−19.2** | Strongest — bass-dominant profile (family norm) |
| 120–250 Hz lowmid | −22.3 | Clean: 3.1 dB below bass, no mud build |
| 250–500 Hz mid | −26.8 | Steep descent begins |
| 500 Hz–1 kHz | −29.8 | |
| 1–2 kHz upmid | −32.8 | |
| 2–4 kHz presence | **−33.7** | Recessed |
| 4–8 kHz brilliance | **−34.3** | Recessed |
| 8–16 kHz air | **−34.2** | **Flat dark top:** presence/brilliance/air within 0.6 dB — Overthinkk-type profile, *not* ATTSS2's rolled-off air |
| 16 kHz+ ultra | −43.1 | Normal roll-off (lossless source; no HF cliff probe needed) |

**Key issues:** very quiet source needing ~+10 dB of competitive gain; uniformly dark top (bass→air tilt 15.0 dB); positive DC offset above threshold; phase minimum −0.822 prohibiting widening.

---

## Sibling-Reference Tuning (deltas, not a template)

Nearest siblings: the 48 kHz **Hardcore_Pop_2** sources — `All_the_Things_She_Said_Hardcore_Pop_2` (quiet + very dynamic + rolled-off air) and `Overthinkk_Hardcore_Pop_2` (loud + flat dark top).

| Decision | This track | Sibling precedent | Why the delta |
|---|---|---|---|
| Low-mid cut | −0.8 dB @ 220 Hz Q1.1 | = ATTSS2 | Lowmid equally clean here; gain insurance only |
| Presence | +1.2 dB @ 3.2 kHz Q1.2 | = ATTSS2 | Same graduated HF ladder entry point |
| Brilliance | +1.5 dB @ 6 kHz Q1.0 | = ATTSS2 | Equally recessed |
| Air | **+2.0 dB @ 11 kHz Q0.7** | Overthinkk +2.0, **not** ATTSS2 +2.5 | Air sits *level with* brilliance (flat dark top), not below it — moderated lift, no over-brightening |
| Bass | **none** | family rule | Bass already strongest; boosting risks boom under +9.6 dB |
| Glue | **1.5:1 @ −15 dB**, 20 ms / 180 ms, knee 4, makeup 1.5 | lighter than ATTSS2's 1.8:1 @ −18 | Source already compact (LRA 4.2 / crest 10.7) — cohesion, not density |
| Widening | **SKIP** (m=1.00 inert, stage retained) | family default | corr_min −0.822 fails the `> 0.0` gate — decided by `family_policy.sh`, not per-track reasoning |
| Bass-mono | **OFF** (policy default) | family default | Mono fold-down passed (below); the negative correlation remains a mix-stage item |
| DC stage | **re-enabled**, `dcshift=-0.000419` | conditional stage | +0.000419 exceeds threshold; note inverted sign vs prior tracks. Verified → 0.000000 after Stage A |

---

## Mastering Chain (as executed by `master_pipeline_v3.sh`)

All processing 32-bit float internally, 48 kHz native end-to-end. Every stage WAV retained in `intermediate/`.

### Stage A — Prep
`volume=-6dB, dcshift=-0.000419, highpass=f=25:poles=2` — headroom, DC null (measured 0.000000 after), 12 dB/oct subsonic filter.

### Stage B — Parametric EQ (flat-dark-top profile)
`equalizer=f=220:t=q:w=1.1:g=-0.8, f=3200:w=1.2:g=+1.2, f=6000:w=1.0:g=+1.5, f=11000:w=0.7:g=+2.0`

### Stage C — Glue compression
`acompressor=threshold=-15dB:ratio=1.5:attack=20:release=180:makeup=1.5:knee=4`

### Stage C2 — Multiband (conditional)
**Disabled** (policy default). Stage retained in orchestrator.

### Stage D — Low-end / stereo (policy-driven)
`extrastereo=m=1.00` (inert — widening SKIP fired automatically from the diagnostic's `CORR_STATS min=-0.8224`), `volume=-3dB` headroom prep. Bass-mono conditional stage present, OFF.
End-of-D: **−19.6 LUFS / −8.8 dBFS peak**.

### Stage E — Pre-gain → soft-clip → true-peak limit
1. `volume=+9.6dB` (calibrated, see sweep log)
2. **E0:** Airwindows **ClipOnly2** via `lv2apply` (clips only overs, bit-identical elsewhere; 1-sample latency trimmed)
3. **E1:** `aresample=192000 (soxr p28) → alimiter=limit=0.851:level=disabled → aresample=48000 (soxr p28)` — limiter of record; ceiling mapping −1.0 dBTP − 0.4 dB margin
   Module verdict: **true peak −1.4 dBTP [COMPLIANT]**

### Stage F — Deliverables
32f copy; 16-bit via `aresample=osf=s16:dither_method=triangular_hp`; **E2** MP3 path: `alimiter=limit=0.82` → `libmp3lame -b:a 320k -compression_level 0` (CBR).

---

## Calibration Sweep Logs (empirical, through the real E0→E1 module)

**Pre-gain** (end-of-D −19.6 LUFS; shortcut formula predicted +9.6):

| Pre-gain | Integrated | LRA | True peak |
|---|---|---|---|
| **+9.6 dB** | **−10.0 LUFS** | **3.8 LU** | **−1.4 dBTP** ← LOCKED |
| +10.0 dB | −9.7 | 3.7 | −1.4 |
| +10.4 dB | −9.3 | 3.7 | −1.4 |

> **Framework note:** the shortcut landed *exactly* on target here — the first time in the family. The known undershoot is **dynamics-dependent**: this compact source (LRA 4.2) barely engages the limiter at target, so no loudness is eaten. Bracketing remains mandatory practice — it is how we know which regime a source is in.

**MP3 ceiling** (E2, decoded 320k CBR re-measured):

| Ceiling | Decoded MP3 TP | Decoded I |
|---|---|---|
| 0.85 | −1.0 dBTP (no margin) | −10.0 |
| **0.82** | **−1.3 dBTP (PASS)** ← LOCKED | −10.1 |
| 0.80 | −1.4 dBTP | −10.1 |

This source reconstructs **gently** in libmp3lame (like ATTSS2's 0.82; unlike ATTSS1's 0.77 or Overthinkk's 0.80) — re-confirming MP3 overshoot is content-dependent and must be swept per source.

---

## Final Master Metrics

| Metric | Target | 32f WAV | 16-bit WAV | 320 MP3 | Status |
|---|---|---|---|---|---|
| Integrated | −10.0 LUFS | −10.0 | −10.0 | −10.1 | ✓ |
| True peak | ≤ −1.0 dBTP | −1.4 | −1.4 | **−1.3** (decoded) | ✓ |
| LRA | — | 3.8 | 3.8 | 3.8 | preserves 3.8 of the source's 4.2 |

### QC gate (`qc_verify.sh`)
- Spectrogram: `verification/qc/spectrogram.png`
- PLR 8.6 dB; PSR proxy 6.9 dB → **FLAG: PSR < 8**. Context: expected at the −10 house standard; the source arrived compact (crest 10.7 / LRA 4.2) and the master retains 90 % of its LRA — the density is the genre target, not chain damage. The `streaming` profile (−14/−1.5) would clear the gate if a dynamics-first deliverable is ever wanted; available opt-in, default untouched.
- Codec round-trip TP (informational): AAC 256k −0.7 / Opus 192k −0.6 / MP3 320k −1.1 — all below 0 dBTP (no decoder clipping); the dedicated E2 deliverable carries the MP3 guarantee at −1.3.

### Translation (`qc_translation.sh`)
- Renders: phone / earbuds / car / club in `verification/translation/`
- **Mono fold-down (R128 baseline-corrected): raw loss 3.2 LU vs ~3.0 baseline → excess cancellation 0.2 LU → PASS, mono-safe.** The −0.822 correlation *minimum* is momentary; the +0.735 mean carries the fold-down. Widening-skip policy validated again.

### Spectral changes (master − source, RMS dB; +3.6 ≈ level change)

| Band | Abs Δ | Relative shape |
|---|---|---|
| 20–60 Hz | +3.6 | 0.0 — weight kept |
| 60–120 Hz | +3.6 | 0.0 — weight kept |
| 120–250 Hz | +3.5 | −0.1 (clarity cut absorbed) |
| 250–500 Hz | +3.6 | 0.0 |
| 500–1k | +3.9 | +0.3 |
| 1–2 kHz | +4.4 | +0.8 |
| 2–4 kHz presence | +5.5 | **+1.9** |
| 4–8 kHz brilliance | +6.3 | **+2.7** |
| 8–16 kHz air | +6.4 | **+2.8** |
| 16 kHz+ | +5.7 | +2.1 |

Bass→air tilt narrowed **15.0 → 12.2 dB**: the flat dark top opened by ~2–2.8 dB relative while the bass-dominant low end kept full weight.

---

## Determinism Record

Two full independent pipeline runs; **byte-level** comparison (stricter than the audio-MD5 norm — see framework note below):

```
SHA256 6066723f…781f9856  MASTER_32f.wav   [IDENTICAL across independent runs]
SHA256 862b22d4…56a011f1  MASTER_16.wav    [IDENTICAL across independent runs]
SHA256 597f5ca3…5c8f00511 MASTER.mp3       [IDENTICAL across independent runs]
AUDIO-MD5 (f32 native) 3cb267efa467953417137b3f9f26868d  MASTER_32f.wav
AUDIO-MD5 (s16 native) e4d0d95ff1b9873abf0eef0292c6e30c  MASTER_16.wav
=> FULL-PIPELINE DETERMINISM: PASS
```

---

## Deliverables

| File | Format | Use |
|---|---|---|
| `I_ccan_Tell_Hardcore_Pop_2_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival / future re-encoding (note: derives from a 16-bit source; float preserves *processing* precision, it does not add source resolution) |
| `I_ccan_Tell_Hardcore_Pop_2_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | **Canonical distribution master** |
| `I_ccan_Tell_Hardcore_Pop_2_MASTER.mp3` | 320 kbps CBR (E2 ceiling 0.82) | Streaming/preview, true-peak-safe |

## Streaming platform compliance

| Platform | Target | Master @ −10.0 | Result |
|---|---|---|---|
| Spotify / YouTube / Tidal / Amazon | −14 | −10.0 | Turned down ~4 dB; TP −1.4 → no codec clipping |
| Apple Music / Deezer | −16 | −10.0 | Turned down ~6 dB |
| Club / DJ | −8 to −10 | −10.0 | Direct play, house standard |

---

## Family comparison (running record, HP2 branch)

| Track | Source I / LRA | corr_min | Pre-gain | MP3 ceiling | Master I / TP / LRA |
|---|---|---|---|---|---|
| ATTSS_Hardcore_Pop_2 | −13.2 / 7.6 | −0.498 | +10.5 | 0.82 | −10.0 / −1.4 / 5.0 |
| Overthinkk_Hardcore_Pop_2 | −10.8 / — | −0.426 | +7.6 | 0.80 | −10.0 / ≤−1.0 / — |
| **I_ccan_Tell_Hardcore_Pop_2** | **−14.1 / 4.2** | **−0.822** | **+9.6** | **0.82** | **−10.0 / −1.4 / 3.8** |

---

## Framework Notes Carried Forward

1. **`stage_clip_limit.sh` precision bug — FIXED this session.** The module's output `ffmpeg` calls omitted `-c:a pcm_f32le`; FFmpeg's WAV default (`pcm_s16le`) silently truncated the limited master to 16-bit. Consequences until now: the "32f archival" was a byte-identical mislabeled 16-bit file, and Stage F's TPDF dither received already-quantized audio. Fixed by forcing `pcm_f32le` on all three module outputs (E0 trim, E1 default, E1 LSP branch). Precision fix only — no stage removed or behavior changed otherwise. **Carry the fixed module forward; re-cutting earlier v3-era 32f masters is optional (audibility nil at these levels) but the archival labels were inaccurate.**
2. **Audio-MD5 normalization caveat.** `ffmpeg -f md5` *re-encodes to s16 by default* before hashing — it can declare a float and a 16-bit file "identical". Determinism records now use raw **SHA-256** plus native-format audio MD5 (`-c:a pcm_f32le` / `-c:a pcm_s16le` explicitly). This is how the bug in (1) was caught.
3. **Pre-gain undershoot is dynamics-dependent.** First family data point where the shortcut formula landed exactly (compact LRA 4.2 source; limiter barely engages). High-LRA sources undershoot 0.3–0.9 dB. Bracketing stays mandatory either way.
4. **First positive-sign DC offset** in the family (+0.000419 → `dcshift=-0.000419`). The new `DCSHIFT` parameter added to `master_pipeline_v3.sh` (additive; default `0.0004` preserved byte-for-byte).
5. **v1 diagnostic shipped again** in the project snapshot; v2 (CORR_STATS footer) restored per standing procedure. Recommend replacing the snapshot copy.
6. **`qc_verify.sh` Peak-line grep window** (`grep -A 12 "Summary:"` cuts the Peak line on some outputs) fixed — extraction now greps the full ebur128 output directly.
7. **corr_min −0.822 is the worst family minimum yet** but mean +0.735 and a 0.2 LU fold-down excess show the *minimum* alone overstates risk on this mix. Policy gate (min > 0.0) stays — it's conservative by design — but the mix-stage correlation item remains the upstream fix.

## Directory structure

```
I_ccan_Tell_Hardcore_Pop_2/
├── source/          original WAV (untouched)
├── analysis/        premaster_diagnostic.txt (v2, CORR_STATS)
├── intermediate/    01_prep … 06_limited + 06e2_mp3src (all stages retained)
├── master/          32f / 16-bit TPDF / 320 CBR MP3
├── verification/    determinism_md5.txt, qc/ (report + spectrogram), translation/ (4 renders + report)
└── scripts/         master_pipeline_v3.sh (DCSHIFT param added), master_pipeline_ICT2.sh,
                     premaster_diagnostic.sh (v2), family_policy.sh, stage_clip_limit.sh (FIXED),
                     stage_bass_mono.sh, lv2_stage.sh, qc_verify.sh (FIXED), qc_translation.sh
```
