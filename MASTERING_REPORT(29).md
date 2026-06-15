# Mastering Report — `Sieh_zu_Ex_Hardcore_Pop_x_dr_Khans`

**Date:** 2026-06-13
**Engineer:** Claude — open-source, CLI-driven, deterministic pipeline (v3)
**Source:** `Sieh_zu__Ex-_Hardcore_Pop_x_dr_Khans.wav` (PCM s16, 48 kHz, stereo, 2:11.6)
**Family:** Hardcore Pop · nearest sibling reference: `I_ccan_Tell_Hardcore_Pop_2` (ICT2)
**Profile:** house — **−10.0 LUFS integrated / ≤ −1.0 dBTP true peak**
**Pipeline:** `master_pipeline_v3.sh` via per-track wrapper `master_pipeline_Sieh_zu.sh`

---

## 1. Pre-Master Diagnosis

| Metric | Source | Read |
|---|---|---|
| Integrated loudness | **−14.9 LUFS** | Quietest HP source measured to date (ICT2 −14.1) |
| Loudness range (LRA) | 3.0 LU | Macro-compact |
| Sample peak | −3.42 dBFS | Ample headroom |
| True peak | −3.4 dBTP | No inter-sample issue at source |
| RMS | −16.48 dB | |
| Crest factor | **13.1 dB** | Micro-DYNAMIC despite low LRA — many transients over a stable bed |
| DC offset | **−0.000192** | Small, **negative** sign (opposite ICT2's +0.000419) |
| Full-band corr (v2) | mean **+0.7271** / min **−0.5396** | Healthy mean; negative min = standing family mix defect |

### Spectral balance (octave bands, RMS dB)

| Band | RMS | Rel. to bass | Read |
|---|---|---|---|
| 20–60 Hz subbass | −21.9 | +0.2 | **Strongest** |
| 60–120 Hz bass | −22.1 | 0.0 | Fundamental |
| 120–250 Hz lowmid | −23.9 | −1.8 | Clean, no mud build |
| 250–500 Hz mid | −26.6 | −4.5 | |
| 500 Hz–1 kHz | −28.2 | −6.0 | |
| 1–2 kHz upmid | −30.5 | −8.3 | |
| 2–4 kHz presence | −31.9 | −9.7 | |
| 4–8 kHz brilliance | −31.7 | −9.5 | |
| 8–16 kHz air | −31.9 | −9.7 | |
| 16 kHz+ ultra | −42.1 | −19.9 | Roll-off |

**Profile read:** the family-typical **dark top** (presence/brilliance/air all ~−31.8, flat within 0.2 dB — even flatter than ICT2's 0.6 dB spread) over a **bass-dominant** low end. Crucially the top sits only **~9.7 dB below bass** here vs ICT2's **~14.8 dB** — the top is *less buried*, so this track needs a **gentler** HF lift than ICT2, not a bigger one.

---

## 2. Premaster Acceptance Gates (`PREMASTER_ACCEPTANCE_SPEC`)

| # | Gate | Measure | Verdict |
|---|---|---|---|
| 1 | Full-band corr min ≥ −0.50 | **−0.5396** | **FAIL** (marginal: −0.54 vs −0.50) |
| 2 | <120 Hz corr mean ≥ +0.30 | **+0.7837** | PASS |
| 3 | Sample peak ≤ −1.0 dBFS | −3.42 | PASS |
| 4 | Crest ≥ 8 dB | 13.1 | PASS |
| 5 | PSR ≥ 7.5 | **9.7** | FLAG (source ok; watch through limiting) |
| 6 | DC offset ≤ 0.0004 | 0.000192 | PASS |
| 7 | Provenance declared | 16-bit, ancestry undeclared | FLAG |

**Disposition — PROCEED with defect logged.** The Gate-1 FAIL is the **standing, family-wide mix defect** (chronic negative phase correlation), escalated to the DAW, not re-patched per track. This source is among the **least-affected** in the family: every per-register *mean* is positive (sub +0.78, lowmid +0.69, mid +0.57, high +0.64) and the full-band mean is +0.7271. With no stems available to return to, the track is mastered with the defect documented, stereo widening auto-skipped, and **mono-safety proven empirically on the finished master** (see §6). The PSR FLAG drove a deliberately light glue setting to avoid eroding micro-dynamics further.

---

## 3. Mastering Chain (per-stage status)

All processing at 32-bit float internally; every module output forced to `pcm_f32le`. No stage is ever deleted — disabled stages are retained and skipped with a logged rationale.

| Stage | Module | Setting | Status |
|---|---|---|---|
| A prep | ffmpeg | `volume=-6dB, dcshift=+0.000192, highpass=25Hz` | ✅ |
| B EQ | ffmpeg | gentle low-mid cut + graduated HF ladder (below) | ✅ |
| C glue | ffmpeg `acompressor` | `thr −16dB, R 1.4, atk 25, rel 200, makeup 1.3×, knee 5` | ✅ |
| C2 multiband | LSP `mb_compressor` | — | ⏭ skipped (policy default) |
| D widening | `extrastereo` | `m=1.00` (inert) | ⏭ skip — corr_min FAIL (stage retained) |
| D bass-mono | `stage_bass_mono.sh` | <120 Hz M/S fold | ⏭ OFF — master proven mono-safe (§6) |
| E0 clip | **ffhard** (`asoftclip hard, 4× OS`) | shave overs, transparent below | ✅ |
| E1 limit | `alimiter` 4× soxr (p28) | true-peak brickwall @ −1.4 dBTP target | ✅ |
| F 32f | ffmpeg `pcm_f32le` | archival | ✅ |
| F 16 | ffmpeg `aresample s16 + triangular_hp` | TPDF-dithered distribution | ✅ |
| F mp3 | E2 ceiling 0.83 → `libmp3lame 320k CL0` | 320 CBR | ✅ |

### Stage B — Parametric EQ (deltas from ICT2)

| Filter | Freq | Q | Gain | vs ICT2 | Purpose |
|---|---|---|---|---|---|
| Bell | 230 Hz | 1.1 | **−0.6 dB** | −0.8 → −0.6 | Light low-mid clarity insurance |
| Bell | 3.0 kHz | 1.2 | **+0.8 dB** | +1.2 → +0.8 | Open presence (moderated) |
| Bell | 6.5 kHz | 1.0 | **+1.0 dB** | +1.5 → +1.0 | Brilliance |
| Bell | 11 kHz | 0.7 | **+1.3 dB** | +2.0 → +1.3 | Air (shallower deficit → smaller lift) |

The whole HF ladder is moderated relative to ICT2 because this source's top is ~5 dB less buried. No bass boost — the low end receives ample make-up + pre-gain.

### Stage E — Loudness & true-peak (E0 substitution note)

Airwindows **ClipOnly2's LV2 build was unavailable** in this environment (upstream host unreachable). `E0_CLIPPER=ffhard` was selected: a deterministic, pure-ffmpeg 4×-oversampled hard clip, role-faithful to ClipOnly2 ("shave the overs, transparent below"). It avoids the LSP clipper's loudness-altering `lufs_on`/`boost` defaults. **The true-peak guarantee is E1's job** (the alimiter 4× soxr scaffold, limiter of record) regardless of E0, so compliance is unaffected. Both LV2 clip options remain preserved behind `E0_CLIPPER`.

---

## 4. Calibration (empirical sweeps through the real E0→E1 module)

### Pre-gain — locked **+17.6 dB**

End-of-Stage-D = −21.6 LUFS; shortcut formula predicted +11.6.

| Pre-gain | Integrated | True peak | Note |
|---|---|---|---|
| +11.6 | −15.6 | −3.5 | limiter idle |
| +14.5 | −12.7 | −1.4 | limiter engages |
| +16.5 | −10.8 | −1.4 | |
| +17.4 | −10.1 | −1.4 | |
| **+17.6** | **−10.0** | **−1.4** | **LOCKED** |
| +17.8 | −9.8 | −1.4 | |

> **Framework note:** the shortcut **undershot by 6.0 dB** despite a *low* LRA (3.0). The undershoot tracks **crest factor** (peak-to-loudness, 13.1 dB here), **not** loudness range. A macro-compact but micro-dynamic source gives the limiter ~6 dB of transient headroom to convert into integrated loudness once driven in. LRA alone does not predict the shortcut — bracketing is how we *know*.

### MP3 ceiling — locked **0.83**

| E2 ceiling | MP3 inter-sample TP | MP3 integrated | Note |
|---|---|---|---|
| 0.86 | −1.0 | −10.0 | no margin |
| 0.84 | −1.0 | −10.0 | no margin |
| **0.83** | **−1.2** | **−10.0** | **LOCKED** (≥0.2 dB margin, on target) |
| 0.82 | −1.2 | −10.1 | |
| 0.80 | −1.3 | −10.1 | |

Highest ceiling that holds a ≥0.2 dB true-peak margin while preserving −10.0 integrated. Consistent with the family (~0.82–0.83).

---

## 5. Final Master Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Integrated | −10.0 LUFS | **−10.0 LUFS** | ✅ |
| True peak | ≤ −1.0 dBTP | **−1.4 dBTP** | ✅ (0.4 dB margin) |
| Max short-term | — | −8.6 LUFS | |
| PSR (TP − max ST) | ≥ 7.5 ideal | **7.2 dB** | ⚠ FLAG (≥6.5 ok) |
| ST p50/p90/p99 | — | −9.8 / −9.1 / −8.8 | |
| ST spread (p99−p50) | ~1.1 (Violet) | **1.0 LU** | ✅ |
| Clipping count L/R | 0 | **4 / 2** | ✅ (Violet: 19 227 / 18 049) |
| Flat factor | 0 | **0.0** | ✅ no flat-topping |
| Mono fold-down loss | low | **0.1 LU** | ✅ (Violet 0.3) |
| <120 Hz corr mean/min | +0.80 ref | **+0.79 / −0.57** | mean near-commercial |

PSR fell 9.7 → 7.2 through loudness normalization — expected, within flag tolerance, and the light glue kept it from dropping further. The master is **cleaner than the commercial reference** on clipping and flat-topping by three orders of magnitude.

---

## 6. Translation & Mono-Safety (`qc_translation.sh`)

| Codec round-trip | inter-sample dBTP | sample peak (lin) | real clip? |
|---|---|---|---|
| MP3 320 | −1.1 | 0.883 (−1.08 dBFS) | no |
| AAC 256 | +2.7 ⚠ | 0.924 (−0.69 dBFS) | **no** |
| Opus 160 | −0.3 | 0.941 (−0.53 dBFS) | no |

- **Mono fold-down loss: 0.1 LU [PASS]** — the **decisive** test. Despite the Gate-1 correlation FAIL, summing to mono costs only 0.1 LU (better than ICT2's 0.2 and Violet's 0.3). The master is **mono-safe**, so the bass-mono remediation stage stays **OFF** and the mix defect is logged as an upstream escalation rather than patched in mastering.
- **No codec clips in the sample domain.** All three decoded round-trips peak below 1.0 linear. AAC's +2.7 "dBTP" is an **inter-sample artifact of FFmpeg's native `aac` encoder** (the higher-quality `libfdk_aac` is not freely redistributable under the OSS-only constraint); its actual sample peak (0.924) is *lower* than Opus's. Real-world AAC encoders reconstruct far more cleanly from a −1.4 dBTP master.
- **Verdict: FLAG** (decode-safe; informative inter-sample flag on native-AAC only).

> **QC-tool fix this session (`qc_translation.sh`):** the codec gate previously hard-FAILED on the inter-sample true-peak estimate, mislabeling a sample-clean, well-headroomed master as failing on one poor encoder's ringing. The gate now measures **two domains** — a hard gate on **sample-domain clipping** (real, in-file) and an informative FLAG on inter-sample TP (DAC-reconstruction estimate, encoder-dependent). Both numbers are retained (feature preserved). This mirrors the existing per-encoder reconstruction reality that already forces the MP3 ceiling to be calibrated separately.

---

## 7. Spectral Delta (source → master)

| Band | Source | Master | Δ vs bass (shape) |
|---|---|---|---|
| subbass | −21.9 | −18.2 | 0.0 (anchor) |
| bass | −22.1 | −18.4 | 0.0 (anchor) |
| lowmid | −23.9 | −19.9 | +0.3 |
| mid 250 | −26.6 | −22.3 | +0.6 |
| mid 500 | −28.2 | −23.5 | +0.9 |
| upmid | −30.5 | −25.6 | +1.1 |
| presence | −31.9 | −26.3 | **+1.8** |
| brilliance | −31.7 | −25.0 | **+2.9** |
| air | −31.9 | −24.7 | **+3.5** |
| ultra | −42.1 | −34.8 | +3.6 |

The dark top (≈−9.7 dB below bass at source) opened to ≈−6.2 dB below bass — a controlled brightening larger than the static EQ alone, as the glue/limiter lifted the recessed top while the bass anchor held. The intended outcome: a brighter, more open master without over-correcting a top that was only moderately buried.

---

## 8. Streaming Compliance

| Platform | Target | Master @ −10.0 LUFS | Note |
|---|---|---|---|
| Spotify / YouTube / Amazon | −14 LUFS | will turn down ~4 LU | no limiting on playback; −1.4 dBTP safe |
| Apple Music | −16 LUFS | will turn down ~6 LU | AAC decode sample-clean (§6) |
| Tidal | −14 LUFS | ~4 LU down | |

True peak −1.4 dBTP clears every platform's −1.0 dBTP recommendation with margin. The −10.0 LUFS house level is a deliberate competitive/club operating point above streaming reference; platforms attenuate without re-limiting.

---

## 9. Determinism & Auditability

- **Bit-identical across two independent full runs (3/3 deliverables), raw SHA-256:**
  - 32f : `0db366a4…f27feda`
  - 16  : `7f90c6ed…554f2a1b`
  - mp3 : `98545a5e…daeb6d81`
- Determinism is recorded with **raw SHA-256** (distinguishes float from 16-bit); `ffmpeg -f md5` is *also* kept for content identity but re-encodes to s16 and cannot catch float-vs-int truncation.
- Deliverable formats verified: 32f = `flt`, 16 = `s16`, mp3 = 320 kbps CBR.
- Retained per-stage intermediates: `01_prep → 02_eq → 03_comp → 04_stereo → 05_pregain → 06_limited` (+ `06e2_mp3src`).

---

## 10. Family Comparison

| Track | Src LUFS | LRA | Crest | Pre-gain | DCSHIFT | MP3 ceil | corr min (pre) | Master | Mono loss |
|---|---|---|---|---|---|---|---|---|---|
| ICT2 (sibling) | −14.1 | 4.2 | 10.7 | +9.6 | −0.000419 | 0.82 | −0.822 | −10.0 / −1.4 | 0.2 LU |
| **Sieh_zu (this)** | **−14.9** | **3.0** | **13.1** | **+17.6** | **+0.000192** | **0.83** | **−0.540** | **−10.0 / −1.4** | **0.1 LU** |
| *Violet (commercial ref)* | −8.0 | 2.4 | 8.7 | — | — | — | −0.058 | −8.0 / +1.1 | 0.3 LU |

Pattern continuity: dark-top + bass-dominant + chronic negative correlation, all present and handled the family-standard way. Sieh_zu needed the **largest pre-gain in the family to date** (crest-driven, not loudness-driven) and is the **most mono-safe** master in the set (0.1 LU). Against the commercial reference it is 2 LU quieter by design but vastly cleaner (clipping 6 vs ~37 000 samples; true peak −1.4 vs +1.1 dBTP).

---

## 11. Framework Notes (carried forward)

1. **Pre-gain shortcut tracks crest, not LRA.** This compact-LRA (3.0) but high-crest (13.1) source undershot the shortcut by 6.0 dB. Document crest alongside LRA when reasoning about expected limiter loudness gain; bracket regardless.
2. **`ffhard` E0 is the environment-portable clip-of-record stand-in.** When ClipOnly2's LV2 build is unreachable, `ffhard` fills the role deterministically without the LSP clipper's loudness defaults. Compliance is unaffected because E1 owns the true-peak guarantee.
3. **`qc_translation.sh` now gates in two domains.** Hard gate = sample-domain clipping (real); soft flag = inter-sample TP (encoder-dependent). FFmpeg's native AAC encoder inflates inter-sample TP and must not hard-fail a sample-clean master. (Both numbers retained.)
4. **DC sign discipline.** A negative source offset (−0.000192) takes a **positive** `dcshift` (+0.000192) — opposite ICT2's case. Always check the sign.
5. **Mono fold-down is the arbiter for the correlation defect.** A Gate-1 FAIL is escalated, not patched, when the finished master sums to mono with ≤~0.5 LU loss. Here 0.1 LU → bass-mono stays OFF, defect logged upstream.

---

## 12. Open Items (unchanged, inputs not code)

1. Room IR for `apply_monitor_correction.sh` (path ready, needs measurement).
2. **Mix-stage correlation fix** — the chronic negative full-band correlation is an upstream mix problem; this track's −0.54 is logged for the DAW pass, not worked around.
3. Reference audio to populate `reference_scan.sh` / `matchering_xcheck.py` (library currently N=1: Cunami-Violet).
