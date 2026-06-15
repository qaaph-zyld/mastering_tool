# Mastering Pipeline — Upgrade Report (v3)

**Scope:** closure of the five-phase rollout from *Taking an FFmpeg Mastering Pipeline
to World-Class: Assessment & Upgrade Plan*.
**Status:** every scriptable plan step closed, integrated, and verified.
**Environment of record:** FFmpeg 6.1.1, lilv-utils 0.24.22, LSP Plugins 1.2.14,
Airwindows LV2 (built from source), kid3-cli, Matchering 2.0.6, SoX soxr (precision 28).
**Invariants held throughout:** open-source only; per-stage WAV intermediates retained;
MD5-deterministic processing; parameterized scripts; nothing deleted (bypassed stages are
conditionally disabled, never removed).

---

## 1. Executive summary

The pipeline moved from a single linear FFmpeg chain to a modular, policy-driven,
QC-gated system. Eleven new modules plus an integrated orchestrator (`master_pipeline_v3.sh`)
now cover diagnosis, processing, true-peak delivery, multi-format QC, translation testing,
reference comparison, and tagging. The original pipeline is retained verbatim as
`master_pipeline_REFERENCE.sh`.

Everything that could change a current master is **off by default** — bass-mono, the
conditional dynamics stages, and the alternate loudness profiles all preserve the existing
−10 LUFS / −1.0 dBTP result byte-for-byte until explicitly selected.

---

## 2. What was improved (before → after)

| Area | Before | After |
|---|---|---|
| Phase-correlation diagnostic | v1 grepped `aphasemeter` stdout → returned **empty** every session | v2 aggregates per-frame `lavfi.aphasemeter.phase` into mean/min/max + machine-readable `CORR_STATS` footer |
| Stereo-widening decision | Reasoned per track; `extrastereo=m=1.10` applied blindly | Locked rule in `family_policy.sh`: widening only if `corr_min > 0.0`, else held at `m=1.0` (inert, not removed) |
| Low-end mono compatibility | No bass-mono stage | Phase-coherent Stage D (common-mode HP + mono-summed bass); verified to flip low-band correlation negative→positive |
| Soft-clip stage | none | Airwindows **ClipOnly2** (clips only overs, leaves rest bit-identical) |
| True-peak limiting | `alimiter` in 4× soxr scaffold | **Unchanged as limiter of record** — proven compliant; LSP limiter evaluated and *rejected* for true-peak use (see §4) |
| Loudness target | single −10 LUFS | opt-in profiles: `archival` −10/−1.0, `club` −8.5/−1.0, `streaming` −14/−1.5 (default unchanged) |
| QC | manual loudness check | `qc_verify.sh`: spectrogram, LUFS/short-term/LRA/TP, PLR, PSR gate, **codec round-trip true-peak re-check** (AAC/Opus/MP3) |
| Tonal balance | octave-band table only | `tonal_delta.py`: 1/3-octave LTAS vs reference with ±3 dB flagging + plot |
| Translation | none | `qc_translation.sh`: phone/earbuds/car/club renders + **mono fold-down phase diagnostic** (R128 baseline-corrected) |
| Reference library | none | `reference_scan.sh`: CSV of LUFS/LRA/TP/PSR/PLR/tilt/low-band correlation per reference |
| Reference matching | none | `matchering_xcheck.py`: diagnostic-only tonal-delta vs reference (deterministic) |
| Delivery metadata | manual | `metadata_tag.sh`: kid3-cli tags + FFmpeg audio-data MD5 record |
| Monitoring correction | out of scope | `apply_monitor_correction.sh`: `afir` convolution apply path (gain-transparent, channel-correct), ready for a DRC-FIR/AutoEq export |
| Multiband / dynamic EQ | none | available as **conditional** stages via `lv2_stage.sh` (generic latency-compensated LV2 runner) |

---

## 3. Integrated chain (master_pipeline_v3.sh)

```
pre-master diagnostic  (measure before processing)
  A  prep        headroom −6 dB / DC / 25 Hz HPF             [FFmpeg]
  B  EQ          parametric (parameterized)                  [FFmpeg]
  C  glue comp   acompressor (parameterized)                 [FFmpeg]
  C2 multiband   LSP mb_compressor          [conditional, default OFF]
  D  low-end     policy widening decision + bass-mono [policy/module]
  E0 soft-clip   ClipOnly2 (LSP clipper alt)                 [LV2]
  E1 true-peak   alimiter inside 4× soxr scaffold            [FFmpeg]
  F  deliverables 32f / 16-bit TPDF / 320 MP3 (+E2 ceiling)
  QC verify + translation matrix + per-deliverable audio MD5
```

Stages A/B/C/E2 stay in the established FFmpeg form (per-track tuned, parameterized).
D and E are the upgraded modular stages. Pre-gain remains a **per-track bracketed
parameter** (`PREGAIN_DB`) — the formula `target − stageD_loudness` still undershoots once
the limiter engages, so empirical bracketing is unchanged practice.

---

## 4. Key engineering findings & decisions

**LSP limiter rejected for true-peak.** Through `lv2apply`, the LSP limiter does not hold a
true-peak brickwall. With `ovs=Full x4`, output overshot the ceiling by 0.6–0.8 dB across
`boost`/`alr` settings on hot input (e.g. −1.0 dBTP ceiling → −0.2 dBTP out). Its `boost`
(default 1) is a loudness makeup that pushes output above threshold; even `boost=0` did not
guarantee compliance. **Decision:** the `alimiter` 4× soxr scaffold remains the limiter of
record (verified COMPLIANT across drive levels: in +4.9 → out −1.0 dBTP). The LSP limiter is
preserved behind `USE_LSP_LIMITER=1` with an explicit warning.

**ClipOnly2 is bit-transparent.** Built from source (MIT). Hosts via `lv2apply` (zero atom
ports), MD5-deterministic, 1-sample latency (pad/trim compensated). Verified: clipped overs
tamed, unclipped samples bit-identical (0.00 diff at the aligned offset).

**dpl can't meet determinism here.** `lv2apply` cannot host dpl (atom control port). jalv/Carla
host it but only via a realtime JACK graph, which cannot guarantee bit-identical output — so it
cannot satisfy the determinism invariant. Closed as a decision, not a gap; LSP/alimiter cover
the function.

**Bass-mono is phase-coherent by construction.** Common-mode high-pass on L and R (identical
filter → no image twist) plus a mono-summed low-passed bass. Low-band correlation −0.39 → +0.69
on a decorrelated-bass test; high band preserved (0.93 → 1.00); crossover reconstructs flat on
mono (0.015 dB). Cross-validated by the mono fold-down test (raw 7.1 LU loss → 3.1 LU after).

**Mono fold-down needs a baseline.** A perfectly correlated stereo signal already reads ~3.0 LU
above its mono sum (R128 channel-summing). The translation diagnostic subtracts that baseline so
only genuine excess cancellation flags a phase problem.

**afir gain/channel correctness.** `afir` defaults (`gtype=peak`) auto-normalize, and a mono IR
on a stereo signal loses ~3 dB and mis-maps. The monitoring-apply path splits per channel,
convolves through the mono FIR, and rejoins with `gtype=-1` — verified gain-transparent and
shape-accurate (+6 dB test shelf reproduced exactly, unity below).

**Loudness reframe (2026 verified).** Streaming normalizes to ~−14 (Spotify/YouTube/Tidal/Amazon)
and −16 (Apple/Deezer); loud-only services don't lift quiet tracks. −10 is neither optimal for
streaming (gets pulled down) nor maximal for club (where there's no normalization). Hence the
opt-in `club` / `streaming` profiles, with −10 retained as the default house standard.

---

## 5. Verification evidence

- **Determinism:** every processing stage MD5-identical across double runs; full-pipeline
  16-bit and 32f masters MD5-identical across independent runs.
- **True-peak:** clip→limit COMPLIANT across input drive levels (−2.3 / −1.1 / −1.0 dBTP at
  +0 / +8 / +16 dB drive).
- **Diagnostic:** v2 phase block returns real mean/min/max where v1 returned nothing;
  measurements bit-identical across runs.
- **Policy:** widening SKIP on negative `corr_min`, ALLOW on positive — both branches tested.
- **QC:** codec round-trip re-measures post-decode true peak per format; PSR gate passes/flags.
- **Bass-mono / translation / tonal-delta / Matchering / metadata / monitoring-apply:** each
  validated on purpose-built signals as described in §4.

---

## 6. How to run

```bash
export LV2_PATH=/usr/lib/x86_64-linux-gnu/lv2:/usr/lib/lv2:/usr/local/lib/lv2
# default house standard (-10/-1.0):
bash scripts/master_pipeline_v3.sh source/track.wav track_name project_dir
# a deliverable profile:
bash scripts/master_pipeline_v3.sh source/track.wav track_name project_dir streaming
# enable conditional stages for a track:
MULTIBAND_ENABLE=1 BASS_MONO_ENABLE=1 bash scripts/master_pipeline_v3.sh ...
# per-track calibration (always bracket pre-gain):
PREGAIN_DB=7.1 MP3_CEIL=0.80 bash scripts/master_pipeline_v3.sh ...
```

Outputs land under `project_dir/{analysis,intermediate,master,verification}` with the
`MASTERING_REPORT` inputs (diagnostic, MD5 record, QC, translation) populated.

**Install prerequisites once:** LSP (`lsp-plugins-lv2`), lilv-utils, kid3-cli from the distro;
unpack `Airwindows_clippers.lv2.tar.gz` into your LV2 path; `pip install matchering`.

---

## 7. What remains — inputs only, not code

These cannot be produced in any sandbox; each plugs into a script already built and waiting:

1. **Room impulse measurement** (Phase 1 hardware) → feeds `apply_monitor_correction.sh` via
   a DRC-FIR export. Physical treatment + measurement are prerequisites.
2. **Mix-stage correlation fix** — the chronic negative correlation is an upstream mix problem;
   bass-mono attenuates it, the mix resolves it.
3. **Reference tracks** → populate `reference_scan.sh` (target curve) and `matchering_xcheck.py`
   (real cross-check) with your genre references.

---

## 8. Module inventory

| File | Role |
|---|---|
| `master_pipeline_v3.sh` | integrated orchestrator |
| `master_pipeline_REFERENCE.sh` | preserved prior pipeline |
| `premaster_diagnostic.sh` | v2 canonical diagnostic |
| `family_policy.sh` | locked widening rule + loudness profiles + bass-mono params |
| `stage_bass_mono.sh` | Stage D phase-coherent bass-mono |
| `stage_clip_limit.sh` | E0 ClipOnly2 → E1 alimiter 4× (LSP paths preserved) |
| `lv2_stage.sh` | generic latency-compensated LV2 runner (multiband, dynamic EQ) |
| `qc_verify.sh` | spectrogram, loudness, PSR gate, codec round-trip |
| `qc_translation.sh` | translation matrix + mono fold-down diagnostic |
| `tonal_delta.py` | 1/3-octave LTAS delta vs reference |
| `reference_scan.sh` | reference-library CSV scanner |
| `matchering_xcheck.py` | diagnostic reference cross-check |
| `metadata_tag.sh` | tagging + audio-data MD5 record |
| `apply_monitor_correction.sh` | afir monitoring-correction apply path |
| `wsl_run.sh` | WSL2 wrapper with Windows→Linux path translation |
| `vocal_prep.sh` | Mix-based AI vocal artifact reduction (pre-master) |
| `CATALOGUE.md` / `CATALOGUE.csv` | Archive inventory (225 files) |

---

## 9. v4 Additions (2026-06-15)

### 9.1 WSL2 Windows Adaptation
The v3 pipeline was built for native Linux. The user runs Windows 10 with WSL2/Ubuntu 26.04.
Instead of rewriting the entire chain for Windows-native tools, a thin wrapper approach
preserves all v3 semantics:

- **`wsl_run.sh`** translates Windows paths (`D:\Projects\...`) to WSL paths (`/mnt/d/Projects/...`),
  sets `LV2_PATH`, and delegates verbatim to `master_pipeline_v3.sh`.
- **Prerequisites:** `ffmpeg`, `lilv-utils`, `lsp-plugins-lv2`, `python3`, `sox` installed inside WSL2;
  `Airwindows_clippers.lv2.tar.gz` extracted to `/usr/local/lib/lv2/`.
- **Usage from PowerShell:**
  ```powershell
  wsl -d Ubuntu bash /mnt/d/Projects/Mastering_Toolshop/wsl_run.sh \
      "D:\Projects\Mastering_Toolshop\source.wav" track_name [profile]
  ```

### 9.2 Genre Profiles
The original three profiles (`archival`, `club`, `streaming`) were Hardcore-Pop-centric.
v4 adds five genre profiles with preliminary loudness targets and genre-specific EQ/compression
presets, loaded via `policy_genre_presets()` in `family_policy.sh`:

| Profile | LUFS | dBTP | EQ Character | Comp Character |
|---|---|---|---|---|
| `hiphop` | −8.0 | −1.0 | Punchy low-mids, scooped mids, bright top | Ratio 2:1, fast attack |
| `german_rap` | −9.0 | −1.0 | Mid-forward, cleaner sub | Ratio 1.8:1, moderate |
| `german_drill` | −8.0 | −0.8 | Aggressive sub, darkened upper-mids | Ratio 2.5:1, tight |
| `serbian_drill` | −8.5 | −1.0 | Bass-dominant, heavy sub | Ratio 2.2:1, aggressive |
| `house` | −8.5 | −1.0 | Extended sub, warm low-mids, open top | Ratio 1.8:1, gentle |

All profiles are **opt-in** (default remains `archival` −10.0 / −1.0). Each profile is a starting
point — bracket per-track as always, and calibrate against 3–5 commercial references per genre
using `reference_benchmark.sh` before relying on them.

### 9.3 Mix-Based Vocal Humanization (`vocal_prep.sh`)
Suno/AI-generated vocals carry artifacts (metallic sibilance, flat dynamics, synthetic timbre,
over-gated breaths) that the mastering bus cannot fully resolve. Since the user works with
stereo bounces (not separate stems), `vocal_prep.sh` targets the vocal frequency range within
the full mix using only FFmpeg-native filters:

1. **De-ess:** `deesser` on 4–8 kHz (static EQ fallback if `deesser` unavailable)
2. **Boxiness cut:** −0.8 dB @ 400 Hz (common AI vocal buildup)
3. **Presence lift:** +1.0 dB @ 2.5 kHz
4. **Transient emphasis:** +1.2 dB @ 3.5 kHz (attack restoration)
5. **Saturation:** `asoftclip=tanhl` at −2 dB drive (timbre warmth)
6. **Glue compression:** 1.3:1 at −24 dB threshold (micro-dynamics restoration)
7. **Expansion:** 0.8:1 at −40 dB threshold (breath noise restoration)
8. **Headroom:** −1 dB safety

All parameters are overrideable via environment variables. The stage is **conditional**
(`VOCAL_PREP_ENABLE=1`) and runs before `master_pipeline_v3.sh` when enabled via `wsl_run.sh`.
Outputs a `VOCAL_PREP_REPORT.md` with the full filter chain and parameter log.

### 9.4 Archive Catalogue
`CATALOGUE.md` and `CATALOGUE.csv` inventory all 225 files in `Mastering_Toolshop`, grouped by:
Audio (95), Pipeline Script (56), Documentation (35), Verification Artifact (30), Image (6),
Archive (2), Reference Library (1).
