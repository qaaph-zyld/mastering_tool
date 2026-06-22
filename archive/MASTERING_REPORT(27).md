# Mastering Report — `Ffav_Dish_Hardcore_Pop_2`

**Date:** 2026-06-11
**Engineer:** Claude (open-source pipeline — FFmpeg 6.1.1 + LV2)
**Source:** `Ffav_Dish_Hardcore_Pop_2.wav` (16-bit PCM, 48 kHz, stereo, 4:17.68)
**Pipeline:** `master_pipeline_v3.sh` (house archival profile −10.0 LUFS / −1.0 dBTP)
**Family:** Hardcore Pop — 48 kHz "Hardcore_Pop_2" sub-family
**Nearest sibling:** `I_ccan_Tell_Hardcore_Pop_2` (ICT2)

---

## 1. Pre-Master Diagnosis

*Measure before processing — full diagnostic run before any decision.*

| Metric | Source | Read |
|---|---|---|
| Integrated loudness | **−13.8 LUFS** | 2nd-quietest HP2 source (ICT2 −14.1, ATTSS2 −13.2) → large pre-gain |
| Loudness range (LRA) | **4.4 LU** | Compact (≈ ICT2 4.2) → light glue, cohesion not density |
| True peak | **−4.3 dBTP** | Abundant headroom; **not** clipping (unusual for this family) |
| Sample peak | −4.33 dBFS | — |
| Crest factor | ≈ 10.4 dB | Peak − RMS; punchy but compact |
| DC offset | **−0.000096** | **Below** family ~0.0004 threshold → DC stage held inert |
| Phase corr. (mean) | **+0.767** | Healthy → mono fold-down expected safe |
| Phase corr. (min) | **−0.693** | Negative → widening SKIP (less extreme than ICT2's family-worst −0.822) |

### Spectral balance (octave bands, RMS dB)

| Band | RMS | Read |
|---|---|---|
| 20–60 Hz subbass | −19.5 | Strong |
| 60–120 Hz bass | **−19.5** | Tied-strongest — fundamental |
| 120–250 Hz lowmid | −21.1 | Clean, only **1.6 dB** below bass (ICT2 was 3.1 dB) |
| 250–500 Hz mid | −25.7 | Clear, no mud |
| 500 Hz–1 kHz | −30.8 | |
| 1–2 kHz upmid | −34.0 | |
| 2–4 kHz presence | **−34.5** | |
| 4–8 kHz brilliance | **−34.5** | Presence = brilliance |
| 8–16 kHz air | **−35.3** | Air sits 0.8 dB **below** brilliance |
| 16 kHz+ ultra | −45.1 | Roll-off |

**Signature:** bass-dominant, **flat dark top** (presence/brilliance/air all within 0.8 dB — Overthinkk/ICT2 type, *not* ATTSS2's rolled-off-below-brilliance air). Clean low end. The defining "issue" is simply that the dark, recessed top needs a graduated, *moderated* lift — over-brightening is the family failure mode.

---

## 2. Sibling-Reference Tuning (deltas from ICT2, not a template)

| Decision | This track | ICT2 precedent | Why the delta |
|---|---|---|---|
| Low-mid cut | **−1.0 dB @ 220 Hz Q1.1** | −0.8 @ 220 Q1.1 | Lowmid sits only 1.6 dB below bass here (ICT2 3.1 dB) → tighter separation → +0.2 dB more clarity insurance |
| Presence | +1.2 dB @ 3.2 kHz Q1.2 | = ICT2 | Presence −34.5 equally recessed; same HF-ladder entry |
| Brilliance | +1.5 dB @ 6 kHz Q1.0 | = ICT2 | Brilliance −34.5 equally recessed |
| Air | **+2.2 dB @ 11 kHz Q0.7** | +2.0 | Air sits 0.8 dB *below* brilliance here (ICT2 air was level) → +0.2 dB to bring air *up to* brilliance, still moderated (no over-brightening) |
| Bass | **none** | family rule | Bass already tied-strongest; boosting risks boom under +9.6 dB make-up |
| Glue | **1.5:1 @ −15 dB**, 20/180 ms, knee 4, makeup 1.5 | = ICT2 | Source equally compact (LRA 4.4 / crest 10.4 vs ICT2 4.2/10.7) |
| Widening | **SKIP** (m=1.00 inert, stage retained) | family default | `corr_min −0.693` fails the `> 0.0` gate — decided automatically by `family_policy.sh` |
| Bass-mono | **OFF** (policy default) | family default | Mono fold-down passes (§7); negative correlation remains a mix-stage item |
| DC stage | **inert** (`dcshift=0`, stage retained) | ICT2 corrected (+0.000419 was *above* threshold) | −0.000096 is 4× below the ~0.0004 family threshold; HPF nulls residual → 0.000000 after Stage A. **First sub-threshold DC in the family.** |

---

## 3. Mastering Chain (as executed by `master_pipeline_v3.sh`)

All processing 32-bit float internally, 48 kHz native end-to-end. Every stage WAV retained in `intermediate/`. Nothing deleted — bypassed stages held inert.

### Stage A — Prep
`volume=-6dB, dcshift=0, highpass=f=25:poles=2` — headroom; DC stage inert (below threshold); 12 dB/oct subsonic filter. DC verified **0.000000** after A.

### Stage B — Parametric EQ (flat-dark-top profile)
`equalizer=f=220:t=q:w=1.1:g=-1.0, f=3200:w=1.2:g=+1.2, f=6000:w=1.0:g=+1.5, f=11000:w=0.7:g=+2.2`

### Stage C — Glue compression
`acompressor=threshold=-15dB:ratio=1.5:attack=20:release=180:makeup=1.5:knee=4` — light cohesion on a compact source; makeup is a ×1.5 **linear** multiplier.

### Stage C2 — Multiband (conditional)
**Disabled** (policy default). Stage retained in orchestrator.

### Stage D — Low-end / stereo (policy-driven)
`extrastereo=m=1.00` (inert — widening **SKIP** fired automatically from the diagnostic's `CORR_STATS min=-0.6928`), `volume=-3dB` headroom prep. Bass-mono conditional stage present, **OFF**.
**End-of-D: −19.6 LUFS** (identical to ICT2).

### Stage E — Pre-gain → soft-clip → true-peak limit
1. `volume=+9.6dB` (calibrated, see §4)
2. **E0:** Airwindows **ClipOnly2** via `lv2apply` (clips only overs, bit-identical elsewhere; 1-sample latency trimmed)
3. **E1:** `alimiter` inside a 4× soxr (precision 28) oversampled scaffold — the **limiter of record**; LSP limiter remains rejected for the true-peak guarantee (overshoots via `lv2apply`).
   Result: **−1.4 dBFS true peak → COMPLIANT** (≤ −1.0 dBTP ceiling).

### Stage F — Deliverables
32-bit float archival · 16-bit TPDF-dithered distribution master · 320 kbps CBR MP3 via a dedicated **E2** lower-ceiling limiter (`alimiter=limit=0.82`) feeding `libmp3lame -b:a 320k -compression_level 0`.

---

## 4. Calibration sweep logs (empirical — bracketing is how we KNOW)

**Pre-gain** (real E0→E1 module, ceiling −1.0 dBTP):

| Pre-gain | Integrated | True peak | LRA |
|---|---|---|---|
| +9.2 | −10.4 | −1.4 | 4.1 |
| **+9.6** | **−10.0** | **−1.4** | **4.1** |
| +10.0 | −9.7 | −1.4 | 4.1 |
| +10.4 | −9.3 | −1.4 | 4.1 |

→ **LOCKED +9.6 dB → −10.0 LUFS / −1.4 dBTP / LRA 4.1.** The formula shortcut (`target − end-of-D = +9.6`) landed *exactly* — as with ICT2, this compact source (LRA 4.4) barely engages the limiter, so the usual undershoot doesn't appear. Bracketing still mandatory: it is how we confirm, not assume.

**MP3 ceiling** (E2 limit → 320k CBR → decode → re-measure true peak):

| E2 ceiling | Post-decode TP | Verdict |
|---|---|---|
| 0.85 | −0.8 | tight (no margin) |
| **0.82** | **−1.1** | **PASS** |
| 0.80 | −1.2 | PASS |

→ **LOCKED 0.82** (gentle reconstructor, matches ICT2/ATTSS2). libmp3lame's filterbank generates its own reconstruction peaks independent of the WAV ceiling — the E2 stage is a standing framework requirement, calibrated per source.

---

## 5. Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated loudness | −10.0 LUFS | **−10.0 LUFS** | ✓ |
| True peak | ≤ −1.0 dBTP | **−1.4 dBTP** | ✓ |
| Loudness range | < 8 LU | **4.1 LU** | ✓ |
| PLR (TP − I) | ≥ 8 (gate) | **8.6 dB** | ✓ PASS |

### Spectral-shape change (master − source, level-matched −3.46 dB)

| Band | Δshape | Read |
|---|---|---|
| 20–60 sub | −0.13 | Held |
| 60–120 bass | −0.06 | **Held — no boost** (family rule) |
| 120–250 lowmid | −0.19 | Clarity cut |
| 250–500 mid | −0.20 | |
| 500–1k | +0.24 | |
| 1–2k upmid | +0.87 | Ladder rising |
| 2–4k presence | **+2.02** | |
| 4–8k brilliance | **+2.84** | |
| 8–16k air | **+3.00** | Air lifted most — now level with brilliance |
| 16k+ ultra | +2.36 | |

Low end preserved exactly; the graduated HF ladder opens the flat dark top. Post-master the top is cohesive — brilliance −28.2 / air −28.9 (air now 0.6 dB below brilliance, vs 0.8 below in the source) — present without harshness.

---

## 6. QC gate (`qc_verify.sh`)

- Integrated −10.0 LUFS · short-term max −10.0 · LRA 4.1 · true peak −1.4 dBTP
- PLR 8.6 dB · **PLR GATE (≥8) PASS**
- Codec round-trip true-peak re-check (post-decode), master = −1.4 dBTP:

| Codec | Post-decode TP | Note |
|---|---|---|
| Opus 160k | **−0.2 dBTP** | ok (under 0) |
| MP3 320k (direct) | **−0.8 dBTP** | under 0; E2 deliverable path tightens to −1.0 |
| AAC 256k (native FFmpeg) | **+3.6 dBTP** | ⚠ **encoder-attributable** — see framework note §9 |

The AAC overshoot is a known limitation of FFmpeg's **native** `aac` encoder on hot, bass-heavy material (decoded sample peak +2.3 dBFS @256k / +1.1 @320k); it is **not** a property of the master and **not** representative of the well-controlled AAC encoders streaming platforms actually use (Apple CoreAudio / libfdk_aac). `libfdk_aac` is not compiled into this distro FFmpeg.

---

## 7. Translation / mono fold-down (`qc_translation.sh`)

| Quantity | Value |
|---|---|
| Stereo I | −10.0 LUFS |
| Mono-sum I | −10.2 LUFS |
| Raw fold-down loss | 0.20 LU |
| R128 summing baseline | 3.0 LU |
| **Excess cancellation** | **−2.80 LU** |
| **Verdict** | **PASS (mono-safe)** |

Excess cancellation is *negative* (well below the +1.5 LU flag) — the mean correlation +0.767 means the mono fold loses far less than the baseline, so there is no destructive cancellation. The negative *minimum* correlation is brief and transient; bass-mono left OFF as a mix-stage matter. Phone/earbuds/car/club audition renders written to `verification/translation/`.

---

## 8. Determinism record (MD5, audio stream)

```
458ade94a77a80aac16606a0f53f6cf0  Ffav_Dish_Hardcore_Pop_2_MASTER_32f.wav
702ea48be4cff17e8e358265ec44ee04  Ffav_Dish_Hardcore_Pop_2_MASTER_16.wav
1e84820d1ee23a3e0d8fa81c0b58be44  Ffav_Dish_Hardcore_Pop_2_MASTER.mp3 (file MD5)
```

Verified **byte-for-byte identical across two independent full-pipeline runs** — 32f, 16-bit, *and* the 320k MP3 all reproduce exactly.

---

## 9. Framework notes carried forward

**LV2 environment reconstructed this session.** The sandbox started without the LV2 stack; rebuilt to match the environment of record: `lilv-utils 0.24.22` (lv2apply) + `lsp-plugins-lv2 1.2.14` from the distro, and **Airwindows ClipOnly2 compiled from source** (MIT; URI `https://hannesbraun.net/ns/lv2/airwindows/cliponly2`) into a minimal LV2 bundle. The genuine E0 ClipOnly2 → E1 alimiter-4x chain ran as designed.

**Re-fixed: `stage_clip_limit.sh` 16-bit truncation (regression in project copy).** The project copy of the module again omitted `-c:a pcm_f32le` on its output ffmpeg calls (E0 atrim, E1 alimiter, and the LSP fallback), so the limited master silently defaulted to `pcm_s16le` — making the "32f archival" a mislabeled 16-bit file and feeding the TPDF dither stage already-quantized audio. This is the exact defect the ICT2 session documented; the fix had not propagated into the canonical module. **Re-applied `-c:a pcm_f32le` to all three module outputs** (precision fix, no feature change). Verified: 32f is now genuine `flt` (98.9 MB) and differs byte-wise from the 16-bit. **The canonical `stage_clip_limit.sh` should be updated to carry this fix permanently.**

**Fixed: `qc_verify.sh` codec round-trip extension bug.** Encoder temp files were written without a container extension, so ffmpeg could not select a muxer and the round-trip true-peak column came back empty. Gave each format a proper extension (`.m4a` / `.opus` / `.mp3`).

**New finding — native FFmpeg AAC is unreliable for the round-trip QC.** It overshoots by several dB on this content; the QC AAC number should be read as encoder behaviour, not master quality. **Recommendation:** when a build with `libfdk_aac` is available, use it for the AAC round-trip; otherwise treat native-AAC overshoot as a flag on the encoder. The master's −1.4 dBTP ceiling plus streaming's playback-gain normalization (−14/−16, attenuating ~4–6 dB before/at transcode) is the real-world safeguard.

**Family record extended.** First sub-threshold DC offset in the family (DC stage legitimately inert). `corr_min −0.693` is the *least* extreme negative minimum recorded so far in the HP2 sub-family (vs ICT2's −0.822), yet still negative → widening correctly held inert by policy.

---

## 10. Deliverables

| File | Format | Use |
|---|---|---|
| `Ffav_Dish_Hardcore_Pop_2_MASTER_32f.wav` | 32-bit float, 48 kHz | Archival / future re-encoding |
| `Ffav_Dish_Hardcore_Pop_2_MASTER_16.wav` | 16-bit PCM, 48 kHz, TPDF dither | **Canonical distribution master** |
| `Ffav_Dish_Hardcore_Pop_2_MASTER.mp3` | 320 kbps CBR (E2 ceiling 0.82) | Streaming / preview |

| Deliverable | Integrated | LRA | True peak |
|---|---|---|---|
| 32f | −10.0 LUFS | 4.1 | −1.4 dBTP |
| 16-bit | −10.0 LUFS | 4.1 | −1.4 dBTP |
| MP3 320 | −10.1 LUFS | 4.1 | −1.0 dBTP |

---

## 11. Streaming platform compliance

| Platform | Norm. target | Master @ −10.0 | Result |
|---|---|---|---|
| Spotify / YouTube / Tidal / Amazon | −14 LUFS | −10.0 | Turned down ~4.0 dB at playback |
| Apple Music / Deezer | −16 LUFS | −10.0 | Turned down ~6.0 dB at playback |
| Club / DJ use | −8 to −10 | −10.0 | Direct play, ideal |

True peak −1.4 dBTP leaves headroom for lossy re-encoding. Note: streaming services apply their normalization gain at playback and use well-controlled AAC/Opus encoders, so the native-AAC overshoot in §6 does not apply to their delivery path.

---

## 12. Reproduce

```bash
export LV2_PATH=/usr/lib/x86_64-linux-gnu/lv2:/usr/lib/lv2:/usr/local/lib/lv2:/usr/local/lib/x86_64-linux-gnu/lv2
bash scripts/master_pipeline_Ffav_Dish.sh source/Ffav_Dish_Hardcore_Pop_2.wav Ffav_Dish_Hardcore_Pop_2 .
```

Locked parameters (in the wrapper): `PREGAIN_DB=9.6 · DCSHIFT=0 · MP3_CEIL=0.82 · EQ_CHAIN(above) · COMP(above)`. Directory layout: `source / analysis / intermediate / master / verification / scripts`.

### Prerequisites (once)
```bash
apt-get install -y lilv-utils lsp-plugins-lv2 lv2-dev   # lv2apply + LSP 1.2.14
# Airwindows ClipOnly2 (MIT) — build the single plugin into an LV2 bundle:
git clone --depth 1 https://github.com/hannesbraun/airwindows-lv2.git
gcc -O2 -fPIC -shared -o ClipOnly2.so airwindows-lv2/src/ClipOnly2/ClipOnly2.c -lm
# place ClipOnly2.so + ClipOnly2.ttl + a manifest.ttl into /usr/local/lib/lv2/ClipOnly2.lv2/
```
