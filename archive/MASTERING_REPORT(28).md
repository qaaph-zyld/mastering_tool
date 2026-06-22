# MASTERING REPORT — Love_Language_Hardcore_Pop_2

**Date:** 2026-06-05
**Engineer pipeline:** FFmpeg-only (open source), reproducible, deterministic
**House target:** −10.0 LUFS integrated · ≤ −1.0 dBTP true peak (ALL deliverables)
**Genre family:** Hardcore Pop
**Sibling template:** `All_the_Things_She_Said_Hardcore_Pop_2` (ATTSS2), mastered 2026-06-05
**Tools:** FFmpeg 6.1.1 · SoX resampler (soxr, precision 28) · LAME via FFmpeg

---

## 1. Pre-Master Diagnosis

Diagnostic run with the **v2 premaster script** (the v1 snapshot ships with the broken
grep-based phase-correlation block that returns empty output; v2 was restored at the
start of this session and aggregates per-frame `lavfi.aphasemeter.phase` metadata via awk).

| Metric | Value | Read |
|---|---|---|
| Format | 48 kHz / 16-bit / stereo / 4:27 | native 48 kHz → 192 kHz oversample path |
| Integrated loudness | **−14.5 LUFS** | quiet source (1.3 dB below ATTSS2's −13.2) → large pre-gain needed |
| LRA | **4.3 LU** | **dense** — among the *least* dynamic in the family (ATTSS2 was 7.6) |
| True peak (sample) | −2.5 dBFS | clean headroom, no inter-sample issues incoming |
| Crest factor | ~13.7 dB | moderate |
| DC offset | **+0.000446** | non-negligible (larger than ATTSS2's) → DC removal re-enabled |
| Phase corr. (min) | **−0.637** | fails mono safety → **widening skipped** (family policy) |
| Mid / Side RMS | −17.2 / −22.9 dB | healthy mono-dominant field (side 5.7 dB below mid) |

**Octave-band profile (source):** classic family signature — bass-dominant, dark rolled-off top.

```
20-60Hz subbass   -23.2     2k-4k presence    -34.1
60-120Hz bass     -22.0 ←   4k-8k brilliance  -34.7
120-250 lowmid    -23.1     8k-16k air        -34.8
250-500 mid       -23.3     16k+ ultra        -47.2
500-1k mid        -26.0
1k-2k upmid       -30.4
```
Bass (60–120 Hz) is strongest but only ~1 dB over the surrounding low bands (more
*even* than ATTSS2's clearly bass-led low end). The top rolls off gently and
monotonically — not the sharp air dropout ATTSS2 had — and the air band (−34.8) sits
roughly level with brilliance, marginally *less* dead than ATTSS2's −35.2.

---

## 2. Mastering Chain (stage by stage)

All stages run at **32-bit float** internally; native 48 kHz preserved end-to-end.

| Stage | Process | Settings | Rationale |
|---|---|---|---|
| **A** | Headroom + DC + subsonic HPF | `volume=-6dB`, `dcshift=-0.000446`, `highpass=25Hz/12dB` | DC removal **re-enabled** (offset non-negligible); 25 Hz HPF clears subsonic rumble before gain |
| **B** | Parametric EQ | see below | dark-top + bass-dominant family treatment |
| **C** | Bus compression (glue) | `1.5:1 @ −18dB`, atk 25ms, rel 200ms, knee 4, makeup 1.5 | **gentle** glue — LRA 4.3 is dense, so light ratio (inverts ATTSS2's 1.8) |
| **D** | Stereo + headroom prep | `extrastereo=m=1.00`, `volume=-3dB` | **widening skipped** (min corr −0.637); stage retained in architecture |
| **E1** | 4× oversampled limit (WAV) | `+10.8dB` → 192 kHz soxr p28 → `alimiter limit=0.85` → 48 kHz | true-peak limiting for lossless masters |
| **E2** | 4× oversampled limit (MP3 src) | identical chain, `alimiter limit=0.82` | dedicated lower ceiling feeding the lossy encode only |

**Stage B — EQ moves** (deltas vs ATTSS2 documented):

| Freq | Gain | Q | Purpose | vs ATTSS2 |
|---|---|---|---|---|
| 230 Hz | −0.7 dB | 1.1 | low-mid clarity insurance under big gain | gentler (−0.8 → −0.7); low end more even here |
| 3.2 kHz | +1.5 dB | 1.2 | presence lift | stronger (+1.2 → +1.5); presence −34.1 more recessed than ATTSS2's −30.4 |
| 6 kHz | +1.5 dB | 1.0 | brilliance / definition | matched |
| 11 kHz | +2.2 dB | 0.7 | broad air lift | **restrained** (+2.5 → +2.2); top less dead + source already dense |

*No low-end boost:* bass is already the strongest band; boosting under +10.8 dB make-up
would risk boom. Framework features (DC removal, widening) are **disabled conditionally,
never deleted** — both remain in the chain for future sources that warrant them.

---

## 3. Gain Calibration (empirical sweep — not the shortcut formula)

Stage-D loudness measured at **−20.2 LUFS**. The "target − stage-D" shortcut predicted
**+10.2 dB**; as expected for a dynamic-leaning chain it **under-shot by 0.6 dB**.

**Pre-gain sweep @ ceiling 0.85:**

| Pre-gain | Integrated | True peak |
|---|---|---|
| +10.5 | −10.2 | −1.4 |
| +10.7 | −10.1 | −1.4 |
| **+10.8** | **−10.0** | **−1.4** ← LOCKED |
| +10.9 | −10.0 | −1.4 |
| +11.0 | −9.9 | −1.4 |
| +11.5 | −9.6 | −1.4 |
| +12.0 | −9.4 | −1.4 |

**MP3 ceiling sweep @ +10.8** (actual encoded 320k CBR measured — libmp3lame adds its own
filterbank reconstruction peaks independent of the WAV ceiling):

| MP3 ceiling | MP3 integrated | MP3 true peak |
|---|---|---|
| 0.85 | −10.0 | −1.0 (on the limit, zero margin — rejected) |
| **0.82** | **−10.1** | **−1.3** ← LOCKED (safe 0.3 dB margin) |
| 0.80 | −10.3 | −1.5 |
| 0.78 | −10.4 | −1.6 |

Like ATTSS2, this source reconstructs gently in libmp3lame, so 0.82 suffices (Part-1-style
sources needed 0.77). MP3 encoded with `-b:a 320k -compression_level 0` (CBR; `-q:a 0`
would trigger VBR).

---

## 4. Spectral Delta (source → master, 32f)

| Band | Source | Master | Δ |
|---|---|---|---|
| 20-60 subbass | −23.2 | −19.3 | +3.9 |
| 60-120 bass | −22.0 | −18.1 | +3.9 |
| 120-250 lowmid | −23.1 | −19.2 | +3.9 |
| 250-500 mid | −23.3 | −19.1 | +4.2 |
| 500-1k mid | −26.0 | −21.6 | +4.4 |
| 1k-2k upmid | −30.4 | −25.6 | +4.7 |
| 2k-4k presence | −34.1 | −28.3 | **+5.8** |
| 4k-8k brilliance | −34.7 | −27.9 | **+6.9** |
| 8k-16k air | −34.8 | −27.7 | **+7.1** |
| 16k+ ultra | −47.2 | −40.3 | +6.9 |

A clean monotonic upward tilt: the ~+3.9 dB floor is the broadband make-up gain; the top
bands gained roughly **+1.9 / +3.0 / +3.2 dB above the floor** (presence / brilliance / air)
— exactly the dark-top correction, achieved without sacrificing low-end weight or
introducing boom.

---

## 5. Streaming / Platform Compliance

| Deliverable | Format | Integrated | True peak | LRA | Status |
|---|---|---|---|---|---|
| `_MASTER_32f.wav` | 48k / 32-bit float | −10.0 LUFS | −1.4 dBTP | 3.1 | ✅ archival |
| `_MASTER_16.wav` | 48k / 16-bit TPDF | −10.0 LUFS | −1.4 dBTP | 3.1 | ✅ distribution |
| `_MASTER.mp3` | 320k CBR joint-stereo | −10.1 LUFS | −1.3 dBTP | 3.0 | ✅ lossy |

All deliverables meet the house standard (−10 LUFS / ≤ −1.0 dBTP). At −10 LUFS the
masters sit hotter than streaming reference (Spotify/Apple/YT ≈ −14 LUFS) by design for
club/DJ use; platforms will normalize down without clipping since true peak is safely
under −1.0 dBTP on every deliverable.

**Determinism:** independent pipeline re-run → 32f and 16-bit WAVs MD5-identical;
MP3 decoded-PCM MD5-identical. Fully reproducible.

---

## 6. Project Directory Structure

```
Love_Language_Hardcore_Pop_2/
├── source/            Love_Language_Hardcore_Pop_2.wav  (read-only original)
├── analysis/          premaster_diagnostic.txt · spectral_delta.txt
├── intermediate/      01_prep · 02_eq · 03_comp · 04_stereo ·
│                      05_limited · 05_limited_mp3src   (all 32f, retained)
├── master/            _MASTER_32f.wav · _MASTER_16.wav · _MASTER.mp3
├── verification/      final_loudness.txt · determinism_md5.txt · calibration_sweeps.txt
└── scripts/           premaster_diagnostic.sh (v2) ·
                       master_pipeline_LoveLanguage2.sh ·
                       master_pipeline_REFERENCE.sh (prior = ATTSS2) ·
                       calibrate_pregain.sh
```

---

## 7. Session Notes / Framework Maintenance

- **Recurring v1 diagnostic bug hit again.** The snapshot shipped the broken v1
  `premaster_diagnostic.sh`; v2 was restored at session start. **Recommendation: make
  v2 canonical in the snapshot** to eliminate this per-session maintenance step.
- **Glue choice inverted from sibling.** ATTSS2 (LRA 7.6, dynamic) used 1.8:1; this
  source (LRA 4.3, dense) used 1.5:1 — confirming the family rule *tighter LRA → gentler ratio*.
- **Widening skipped** for the 13th+ consecutive family track (min corr −0.637). The
  negative-min-correlation → mono-safety pattern is now effectively universal across
  the Hardcore Pop family; stage is retained but consistently inert.
- All framework features preserved; nothing deleted.
