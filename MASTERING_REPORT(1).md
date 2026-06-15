# Mastering Report — `Overthinkk_Hardcore_Pop_2`

**Date:** 2026-06-05
**Engineer:** Claude (FFmpeg-only pipeline, open-source)
**Source:** `Overthinkk_Hardcore_Pop_2.wav` (16-bit PCM, 48 kHz, stereo, 5:21)
**House standard:** −10.0 LUFS integrated · ≤ −1.0 dBTP true peak (all deliverables)
**Toolchain:** FFmpeg 6.1.1 · soxr (precision 28) · libmp3lame · all open-source

---

## Reference template

Derived from the nearest available sibling, **`All_the_Things_She_Said_Hardcore_Pop_2`** — the other 48 kHz Hardcore Pop "Part 2," architecturally identical (48 kHz native → 192 kHz 4× oversample). No `Overthinkk_Hardcore_Pop_1` was present in this session's reference set, so deltas are documented against ATTSS2 and the broader Hardcore Pop family patterns rather than a direct Part 1. Prior pipeline preserved as `scripts/master_pipeline_REFERENCE.sh`.

> **Framework note (recurring):** the project snapshot again shipped the broken **v1** `premaster_diagnostic.sh` (grep-based phase-correlation block → empty output). The **v2** fix (per-frame `aphasemeter.phase` aggregated to mean/min/max via awk, plus a mid/side RMS cross-check) was restored at the start of this session. Making v2 canonical in the snapshot would eliminate this step every track.

---

## Pre-Master Diagnosis

| Metric | Source | Read |
|---|---|---|
| Integrated loudness | **−10.8 LUFS** | **Loudest source in the recent family** — only +0.8 dB to target |
| Loudness range (LRA) | 4.9 LU | Moderate dynamics |
| True peak | **−1.1 dBTP** | Clean — hot but not clipping |
| Sample peak | −1.14 dBFS | Hot |
| Crest factor | 11.1 dB | Moderate transient life |
| DC offset | **−0.000706** | Above the family's ~0.0005 negligible threshold → **correction re-enabled** |
| Phase corr (mean / min) | +0.746 / **−0.426** | Min fails mono-safety → **widening skipped** |
| Frames < 0 / < −0.2 | 0.2% / 0.1% | Anti-phase is rare/transient, but the dips are deep |
| Side vs Mid RMS | **−15.8 dB** | Already narrow / mono-centred |

### Spectral balance (octave bands, RMS dB)

| Band | RMS | Read |
|---|---|---|
| 20–60 Hz subbass | **−17.55** | Strongest band — marginally sub-led |
| 60–120 Hz bass | **−17.80** | Co-dominant fundamental |
| 120–250 Hz lowmid | −19.34 | Builds under the strong bass |
| 250–500 Hz mid | −22.05 | |
| 500 Hz–1 kHz | −24.60 | |
| 1–2 kHz upmid | −27.49 | |
| 2–4 kHz presence | −28.85 | Recessed (most recessed top band) |
| 4–8 kHz brilliance | −28.44 | Recessed (most-alive top band) |
| 8–16 kHz air | −29.02 | Dark |
| 16 kHz+ ultra | −38.33 | Roll-off |

**Profile:** bass-dominant with a dark top (sub→air slope 11.5 dB), but the top is **flat and evenly recessed** — presence / brilliance / air sit within 0.6 dB of each other (≈ −28.5 to −29). This is *not* the steep roll-off the ATTSS2 sibling had (its air was −35.2, far below brilliance), so the top needs a smooth, even lift rather than aggressive air correction.

**Key decisions from the diagnostic:** no low-end boost (already strongest), even top lift weighted to the most-recessed presence band, moderated air shelf, DC correction re-enabled, stereo widening skipped, small pre-gain.

---

## Mastering Chain

All processing at 32-bit float internally; native 48 kHz preserved end-to-end. Headroom maintained until the controlled limit at Stage E.

### Stage A — Prep
- `volume=-6dB` — headroom
- `dcshift=0.000706` — **DC correction re-enabled** (−0.000706 is the highest DC in the recent family, above the negligible threshold)
- `highpass=f=25:poles=2` — 12 dB/oct subsonic filter

### Stage B — Parametric EQ (dark, bass-dominant, flat-top profile)
| Filter | Freq | Gain | Q | Purpose |
|---|---|---|---|---|
| Bell | 220 Hz | **−0.8 dB** | 1.1 | Low-mid clarity insurance under make-up gain |
| Bell | 3.2 kHz | +1.2 dB | 1.2 | Presence (most recessed top band) |
| Bell | 7 kHz | +0.8 dB | 1.0 | Brilliance bridge — light touch (most-alive top band, preserve) |
| Shelf-like bell | 12 kHz | +2.0 dB | 0.7 | Broad air lift, **moderated** (top is dark but flat, not steeply rolled off → less than ATTSS2's +2.5) |

*No bass/sub boost — the low end is already the strongest content; boosting under make-up gain would risk boom.*

### Stage C — Bus compression (glue)
`acompressor=threshold=-18dB:ratio=1.5:attack=25:release=200:makeup=1.5:knee=4`

LRA 4.9 (moderate) → **ratio 1.5** — gentler than ATTSS2's 1.8 (whose LRA was 7.6). 25 ms attack preserves transient punch; 200 ms musical release; 4 dB soft knee.

### Stage D — Stereo + headroom prep
`extrastereo=m=1.00,volume=-3dB`

**Widening skipped** (m=1.0): minimum phase correlation −0.426 fails mono-safety, and the image is already narrow (side −15.8 dB below mid). Stage retained in the architecture per framework policy — only the −3 dB headroom prep is applied.

### Stage E — 4× oversampled true-peak limiting
Upsample to **192 kHz** (soxr, precision 28) → `alimiter` → downsample to 48 kHz. Two passes:
- **E1 (WAV masters):** pre-gain **+7.6 dB**, ceiling **0.85** → −1.4 dBTP
- **E2 (MP3 source):** pre-gain +7.6 dB, ceiling **0.80** → MP3 −1.3 dBTP

---

## Gain Calibration (empirical sweep, not the shortcut formula)

End-of-Stage-D loudness was **−17.3 LUFS**. The "target − stage-D" shortcut predicted +7.3 dB; it under-shot by 0.2 LU here (small, because the source is already loud and LRA tightened post-glue).

| Pre-gain | Integrated | True peak |
|---|---|---|
| +7.3 dB | −10.2 LUFS | −1.4 dBTP |
| **+7.6 dB** | **−10.0 LUFS** | **−1.4 dBTP** ← locked |
| +8.0 dB | −9.7 LUFS | −1.4 dBTP |
| +8.5 dB | −9.4 LUFS | −1.4 dBTP |
| +9.0 dB | −9.1 LUFS | −1.4 dBTP |

### MP3 ceiling sweep (libmp3lame reconstructs its own filterbank peaks)
At +7.6 dB pre-gain:

| MP3 ceiling | MP3 true peak | Verdict |
|---|---|---|
| 0.85 | −0.4 dBTP | ✗ fails ≤ −1.0 |
| 0.82 | −0.8 dBTP | ✗ fails ≤ −1.0 |
| **0.80** | **−1.3 dBTP** | ✓ **locked** |

This source reconstructs **hotter** than its ATTSS2 sibling (which passed at 0.82) — the hot, bass-dominant signal drives the LAME filterbank harder, so a dedicated lower MP3 ceiling was required.

---

## Spectral Delta (source → final 32f master)

Absolute band-RMS deltas (include the overall loudness rise; the *tilt* is the point):

| Band | Source | Master | Δ |
|---|---|---|---|
| 20–60 subbass | −17.55 | −17.29 | **+0.26** |
| 60–120 bass | −17.80 | −17.63 | **+0.18** |
| 120–250 lowmid | −19.34 | −19.21 | **+0.13** |
| 250–500 mid | −22.05 | −21.65 | +0.41 |
| 500–1k mid | −24.60 | −23.72 | +0.88 |
| 1k–2k upmid | −27.49 | −26.20 | +1.29 |
| 2k–4k presence | −28.85 | −26.80 | **+2.04** |
| 4k–8k brilliance | −28.44 | −25.87 | **+2.56** |
| 8k–16k air | −29.02 | −26.13 | **+2.89** |
| 16k+ ultra | −38.33 | −35.67 | +2.67 |

The low end is held almost flat (+0.1 to +0.3 dB) while the dark top is opened by +2.0 to +2.9 dB — the intended dark-top / bass-dominant treatment. The smallest mid delta (lowmid +0.13) is the −0.8 dB clarity cut showing through.

---

## Streaming Platform Compliance

| Platform | Target | This master (−10.0 / −1.4 dBTP) |
|---|---|---|
| Spotify / Amazon / YouTube | −14 LUFS, −1 dBTP | Will turn down ~4 dB (loud, competitive); TP-safe |
| Apple Music | −16 LUFS, −1 dBTP | Normalized down; TP-safe |
| Tidal | −14 LUFS | Normalized down; TP-safe |
| Club / DJ / file playback | as-is | Full −10 LUFS house loudness |

All deliverables pass the ≤ −1.0 dBTP ceiling (WAV −1.4, MP3 −1.3).

---

## Deliverables

| File | Format | Integrated | LRA | True peak |
|---|---|---|---|---|
| `Overthinkk_Hardcore_Pop_2_MASTER_32f.wav` | 32-bit float WAV, 48 kHz (archival) | −10.0 LUFS | 3.3 LU | −1.4 dBTP |
| `Overthinkk_Hardcore_Pop_2_MASTER_16.wav` | 16-bit WAV + TPDF dither, 48 kHz (distribution) | −10.0 LUFS | 3.3 LU | −1.4 dBTP |
| `Overthinkk_Hardcore_Pop_2_MASTER.mp3` | 320 kbps CBR MP3, joint stereo (`-compression_level 0`) | −10.1 LUFS | 3.2 LU | −1.3 dBTP |

### Verification
- **Determinism:** all three deliverables byte-identical (MD5) across two independent full-pipeline re-runs.
- **CBR confirmed:** MP3 encoded with `-b:a 320k -compression_level 0` (not `-q:a 0`, which would force VBR).
- **Formats verified** via ffprobe (see `verification/deliverable_formats.txt`).

---

## Project Directory Structure

```
Overthinkk_Hardcore_Pop_2/
├── MASTERING_REPORT.md
├── source/        Overthinkk_Hardcore_Pop_2.wav
├── analysis/      full_diagnostic.txt, spectral_delta.txt
├── intermediate/  01_prep → 02_eq → 03_comp → 04_stereo → 05_limited (+ 05_limited_mp3src)
├── master/        *_MASTER_32f.wav, *_MASTER_16.wav, *_MASTER.mp3
├── verification/  final_loudness.txt, determinism_md5.txt, deliverable_formats.txt
└── scripts/       premaster_diagnostic.sh (v2), master_pipeline_Overthinkk2.sh,
                   master_pipeline_REFERENCE.sh (preserved sibling)
```

All five intermediate 32-bit float stage files retained for auditability per framework.

---

## Framework lessons (this session)

1. **Hottest source to date in the family (−10.8 LUFS)** → smallest pre-gain (+7.6 dB); the shortcut undershoot shrank to 0.2 LU because both the source loudness and post-glue LRA were already close to target.
2. **MP3 ceiling is per-source, not fixed:** this source needed 0.80 where ATTSS2 passed at 0.82. Always sweep the E2 ceiling against an actual encode — hot bass-dominant material reconstructs hotter in libmp3lame.
3. **"Dark" ≠ "rolled off":** a dark-but-flat top (bands within 0.6 dB) gets an even lift with a *moderated* air shelf, distinct from the aggressive air correction a steep roll-off (like ATTSS2's) calls for.
4. **DC threshold matters:** −0.000706 crossed the ~0.0005 line, so correction was re-enabled rather than skipped.
