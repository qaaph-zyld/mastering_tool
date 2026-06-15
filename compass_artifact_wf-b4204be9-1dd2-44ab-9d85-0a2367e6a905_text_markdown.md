# Taking an FFmpeg Mastering Pipeline to World-Class: Assessment & Upgrade Plan

## TL;DR

- **Your engineering discipline is already world-class; your *toolset* and *monitoring* are not.** The gap to commercial masters is a handful of missing processors (transparent true-peak limiter, soft-clip-before-limit, multiband/dynamic EQ, mid/side bass-mono, saturation) plus the room/translation layer — all fixable with scriptable open-source tools while keeping your MD5-deterministic, parameterized, fully-documented framework intact.
- **Highest-leverage moves, in order:** (1) treat the room + add open-source room/headphone correction; (2) stand up an LV2 CLI host path (`lv2apply`/Carla) to use LSP, x42, Zam and Airwindows plugins; (3) replace FFmpeg `alimiter` with x42 `dpl.lv2` or the LSP Limiter and add an Airwindows ClipOnly2 soft-clip stage before it; (4) adopt linear-phase bass-mono (elliptical EQ) as the family default and fix your chronic negative correlation in the *mix*, not the master.
- **Rethink the single −10 LUFS house target.** For streaming it is simply normalized down (Spotify/YouTube/Tidal −14, Apple −16); for club/DJ use it is actually slightly *more* dynamic than the trap norm of −8 to −6 LUFS. Move to deliverable-specific loudness and start logging PSR (keep ≥ 8 in the loudest section).

---

## Executive Summary — Level-Headed Expert Assessment

Nikola, your pipeline is, from an *engineering-discipline* standpoint, already ahead of most amateur and even many professional setups: deterministic, MD5-verified, fully parameterized, per-stage intermediates, documented sessions, codec-aware MP3 limiting. That reproducibility is genuinely rare and valuable. The gap between you and world-class masters is **not** discipline or determinism — it is (1) **a small number of missing signal-processing tools** that the FFmpeg native filter set cannot provide well (true multiband dynamics, dynamic EQ, mid/side processing, harmonic saturation, a soft-clip-before-limit stage, and a genuinely transparent true-peak limiter), and (2) **the monitoring/translation layer**, which on your description is the single weakest link and the one most likely holding your perceived quality back.

The highest-leverage moves, in priority order:

1. **Fix monitoring and translation first.** No processing upgrade matters if you cannot hear what you are doing. An untreated room with consumer gear is the dominant error source. This is cheap to improve dramatically.
2. **Introduce a real LV2 plugin host path** (`lv2apply` for simple stages, Carla headless for chains) so you can use **LSP Plugins**, **x42**, **Zam** and **Airwindows** processors while keeping everything scriptable and MD5-deterministic.
3. **Replace `alimiter` with x42 `dpl.lv2` or the LSP Limiter** as your true-peak limiter, and **add a soft-clip stage (Airwindows ClipOnly2 / ClipSoftly or LSP Clipper) before the limiter** — the biggest single audible quality jump for loud club/hip-hop masters.
4. **Adopt mid/side low-end management (bass-mono below ~120 Hz)** as the family default instead of the full width-skip, and treat your chronic negative correlation as a **mix-stage bug to fix upstream**, not just a mastering symptom.
5. **Reconsider the −10 LUFS house target.** For streaming it is being thrown away by normalization; for club/DJ use it is justified. The right answer is *deliverable-specific* loudness, not one global number.

---

# DELIVERABLE 1 — Critical Gap Analysis vs World-Class Masters

## 1.1 Where you are already at or near professional standard

- **Determinism & auditability.** MD5 double-run verification, retained per-stage WAVs, locked calibration, and a per-session `MASTERING_REPORT.md` exceed what most commercial rooms document. Keep this; it is a competitive advantage and the backbone of everything below.
- **4× oversampled true-peak limiting with soxr precision 28.** Conceptually correct and matches the standard approach (upsample → limit → downsample) recommended by FFmpeg's own `loudnorm` author for true-peak work.
- **Separate lower-ceiling limiter feeding the MP3 path.** Genuinely sophisticated and correct — lossy encoders (MP3/AAC/Ogg/Opus) reconstruct inter-sample peaks above your WAV ceiling, so a tighter ceiling for the lossy path is real codec-aware delivery thinking that many "pro" engineers neglect.
- **Three-tier deliverables (32-bit float archival, 16-bit TPDF dither, 320 CBR MP3).** Format hygiene is correct; TPDF dither on the only down-conversion is right.
- **DC correction, 25 Hz highpass, headroom staging.** Standard, sensible prep.

## 1.2 What genuinely matters and is missing (high impact)

### (a) A transparent true-peak limiter — your `alimiter` is the weakest link
FFmpeg's `alimiter` is a basic look-ahead limiter; the FFmpeg community itself recommends it only as a crude tool, and for true-peak work the documented method is literally "upsample to 4× sample-rate, apply `alimiter`, downsample" — i.e. `alimiter` has *no native true-peak mode*, which is why you built the oversampling scaffold yourself. Its detector/release behavior is not in the same class as dedicated mastering limiters for transparency at the 1–3 dB of gain reduction that defines good mastering. Professional limiters are prized for being able to "handle 2 to 3 dB of gain reduction without the transients changing character"; "a limiter with 8 to 10 dB of gain reduction is destroying the transients."

**Open-source fix:** **x42 `dpl.lv2`** (Robin Gareus's Digital Peak Limiter, based on Fons Adriaensen's DPL-1) is a genuinely professional-grade look-ahead true-peak limiter. Per x42-plugins.com: *"Latency is 1.2 ms, rounded up to the nearest multiple of 8, 16 or 32 samples depending on sampling frequency. This amounts to 56 samples at 44.1 kHz, 64 samples at 48 kHz… The limiter can operate in digital-peak and true-peak mode"* (true-peak detection key is 4× oversampled; *"will not allow a single sample above [threshold]"*). Alternatively the **LSP Limiter** offers dedicated True-Peak modes plus **ALR** (Automatic Level Regulation — an infinite-ratio compressor stage that smooths gain reduction before a separate peak-cutting stage) and Lanczos oversampling up to 8×. Either is a categorical upgrade over `alimiter`.

### (b) No soft-clip / clip-before-limit stage — the #1 loudness-quality lever for your genre
Every serious modern hip-hop/trap/drill mastering description converges on the same chain: **clipper → limiter**. The clipper "shaves off the sharpest, fastest transients with a form of distortion that is often perceived as punch rather than pumping… allowing the final limiter to work less hard and achieve greater overall loudness without audible artifacts." This is *the* technique behind competitive loud masters, and you have nothing equivalent.

**Open-source fix:** **Airwindows ClipOnly2** (MIT-licensed; available as LV2 via the Airwindows Consolidated/LinuxVST builds) is mastering-grade: it passes all unclipped samples *untouched* and only synthesizes soft entry/exit on actually-clipped samples, "stomping on Gibb Effect Nyquist reconstruction overshoots very heavily" while killing digital glare — ideal as a safety/loudness clipper before the limiter (its developer notes you'd "use something like ClipOnly2 in mastering specifically because it won't touch the values of any unclipped samples"). **ClipSoftly** is the saturating-softclip sibling; **ADClip9** adds bass/high energy-fill "loudenator" behavior. The **LSP Clipper / Multiband Clipper** is another deterministic option.

### (c) No multiband compression or dynamic EQ
FFmpeg's `acompressor` is single-band with a linear makeup multiplier; `equalizer` is minimum-phase biquad only. World-class hip-hop mastering "often use[s] multiband compression and limiting" and "dynamic equalizers" to control specific problem bands (e.g. boomy 200 Hz only when the kick hits, harsh 3 kHz only on loud snares) without static cuts that dull the whole track.

**Open-source fix:** **LSP Multiband Compressor** (`http://lsp-plug.in/plugins/lv2/mb_compressor_stereo`) — up to 8 freely-assignable bands, Classic/Modern/Linear-Phase crossover modes, per-band lookahead with automatic phase-compensation latency reporting — is legitimately FabFilter Pro-MB-class. For dynamic EQ: **Zam Audio ZamDynamicEQ** (LV2, well-regarded by Linux audio engineers for taming "painful spikes"), the new **ZL Equalizer 2** (free, open, LV2/VST3/AU on Linux, pitched as a Pro-Q alternative with dynamic bands), or an LSP parametric EQ run dynamically.

### (d) No mid/side processing — and this directly intersects your correlation problem
You have **no M/S EQ or dynamics**, and you handle your chronic **negative phase correlation by skipping widening entirely** (m=1.0). Defensible as a safety choice, but it treats a symptom. World-class practice for bass-dominant club music is **bass-mono / elliptical EQ**: high-pass the *side* channel below ~100–120 Hz so the low end is mono (tight, punchy, translates to mono club PAs and phone speakers) while preserving stereo width above. Critically: a *minimum-phase* side-channel HPF "twists" the stereo image around the cutoff ("you are progressively flipping the stereo image by differing amounts around the cutoff frequency"), so a **linear-phase** implementation is strongly preferred.

**The deeper diagnosis:** persistent negative correlation on *nearly every track* in a family is almost never natural — it points to an **upstream mix problem**: out-of-phase stereo wideners/choruses on instruments, mono sources hard-decorrelated by stereo-spread plugins, or sample packs with anti-phase content. Mastering elliptical EQ can only *attenuate* decorrelation, not fix its cause — as engineers on the mastering forums put it, "standard sum/diff trickery… can only turn it down." The real fix is in the mix.

### (e) No harmonic saturation / "glue" coloration
Analog-style harmonic saturation adds density and perceived loudness and is near-universal in pro mastering. **Open-source fix:** Airwindows console emulations (Console7/Console8 Buss), ToTape (tape), and ZamAutoSat / ZamTube provide deterministic saturation.

### (f) No codec-aware AAC/Opus auditioning or post-encode true-peak re-check
You smartly built a tighter MP3 ceiling, but you don't *measure* the result after encode, and you don't audition AAC (Apple Music) or Opus (YouTube/Spotify Ogg). A WAV at +0.3 dBTP "might measure +1.0 dBTP or higher after [AAC encode]," producing "a hardness, a brittleness on loud transients."

### (g) No spectrogram / tonal-balance visual QC, no reference-matching
You rely on octave-band RMS via highpass/lowpass+astats and aphasemeter aggregation — decent numbers, but no spectrogram and no measured-reference comparison. Pro rooms reference constantly.

## 1.3 Loudness positioning: is −10 LUFS / your LRA competitive?

**Short answer: −10 LUFS integrated is reasonable-to-conservative for club/DJ hip-hop, but it is the *wrong frame* for streaming, where it is simply turned down.**

Current measured commercial reality (2024–2026):
- iZotope's **"Mastering trends in 2024"** study of 54 Billboard Global 200 Top-10 songs found an **average integrated loudness of −8.3 LUFS (±1 LU)**, range spanning **−11.1 LUFS (Taylor Swift, "Who's Afraid of Little Old Me") to −6 LUFS (Tate McRae, "greedy")**, max short-term typically 2–4 LU above integrated, and **"50% of the songs exhibit an LRA between 3.7 and 6.8 LU."**
- Rap/trap/drill specifically: commonly mastered in the **−8 to −6 LUFS** zone for density and club/CD play, "with the understanding that platforms will turn them down"; club/CD rap masters sit roughly **−9 to −6 LUFS**.
- So your **−10 LUFS** is actually *slightly more dynamic* than the trap norm — not over-compressed. Good for quality, but it means on club systems you may be a touch quieter than competitors who push harder.

**Streaming normalization targets, current as of 2026:**
- **Spotify** −14 LUFS (Normal); Loud −11, Quiet −23. Per iZotope, **87% of Spotify users keep normalization on its default setting.** Spotify Support: *"Keep it below -1dB TP (True Peak) max… If your master is louder than -14dB integrated LUFS, keep True Peak below -2dB to avoid extra distortion."*
- **Apple Music** −16 LUFS (Sound Check), AAC 256 kbps.
- **YouTube** −14 LUFS, always-on, **only turns loud tracks down, never boosts.**
- **Tidal / Amazon / SoundCloud / TikTok / Instagram** −14 LUFS (Amazon sometimes cited −13 and uniquely requests −2 dBTP); **Deezer −15**; **Bandcamp no normalization.**
- Real-world: a MasteringTheMix analysis of the top 25 Spotify tracks of 2022 found the **average integrated loudness was −8.4 LUFS** — these get pulled down ~6 dB on Spotify, so "all that aggressive limiting and compression accomplished nothing volume-wise."

**PSR/PLR (dynamics) targets:** The AES-standardized **PSR (Peak-to-Short-Term-loudness Ratio)** is the key micro-dynamics metric — AES e-Brief 373, *"Measuring Micro-Dynamics—A First Step: Standardizing PSR,"* by Shepherd, Grimm, Tapper (Nugen), Kahsnitz (RTW) and Kerr (MeterPlugs), 143rd AES Convention, 8 October 2017. Rule of thumb: **keep PSR above 8 during the loudest sections**; PLR ~12 is "dynamic," ~5 is "squashed"; crest factor of well-mastered tracks is typically 8–12 dB. Measure and log PSR/PLR per master and treat PSR < 8 in the loudest section as a red flag.

**Recommendation:** Move to **deliverable-specific loudness**: keep a hot **−9 to −8 LUFS club/DJ master** (clip+limit, PSR ≥ 8 enforced) and produce a **−14 LUFS, −1 dBTP streaming master** (−2 dBTP if you keep it hot) so streaming services aren't re-limiting your work. Your framework already supports multiple deliverables — this is a parameter change, not an architecture change.

---

# DELIVERABLE 2 — Upgraded Pipeline & Open-Source Toolbox Blueprint

**Framework rules preserved throughout:** never delete a stage (conditional-disable only), parameterized scripts, retained intermediates, MD5 double-run determinism, full `MASTERING_REPORT.md`.

## 2.1 The deterministic plugin-host path (the key enabler)

You can host LV2/LADSPA/VST plugins from the CLI deterministically. Two robust paths:

**(A) `lv2apply` (from lilv / lilv-utils)** — the simplest. Usage (man page confirmed: `-i IN_FILE`, `-o OUT_FILE`, `-c SYM VAL` "Set control port SYM to VAL"):
```
lv2apply -i in.wav -o out.wav -c threshold -1.0 -c release 80 <PLUGIN_URI>
```
Control ports are set by their **lv2:symbol** (not name/index). Packaged on Debian/Ubuntu (`lilv-utils`) and Arch (`lilv`). **Determinism:** offline, no realtime jitter — ideal. **Critical limitation (verify empirically):** lv2apply is described in the official LV2 docs as "a very simple program… to learn the basics," and it does **not** appear to compensate for plugin-reported latency or flush lookahead tails. For look-ahead limiters this means the output is time-shifted by the plugin latency and the final lookahead-length tail is truncated. **Mitigation:** pad input with trailing silence ≥ plugin max latency, then trim the leading latency samples — and verify by feeding a known impulse, measuring the offset, and locking that offset into your script. Confirm latency with `lv2info <URI>`.

**(B) Carla (falkTX), headless** — for multi-plugin chains and robust latency handling. Carla is GPL, hosts LADSPA/DSSI/LV2/VST2/VST3/AU, runs headless, and `carla-single` instantiates a single plugin of a given format. Where sample-accurate chaining and latency compensation matter, Carla (or `jalv`) is more reliable than lv2apply. Packaged as `carla` on KXStudio repos, Fedora and Arch.

**Determinism caveat to flag:** any stage with internal dither or randomness (LSP Limiter's Dither, TPDF dither, some saturators) must be checked with your MD5 double-run method. If a plugin uses an unseeded RNG it will break determinism — verify each, and where dither is needed apply it as the single final, controlled step (as you already do).

**Verified LV2 URIs for the recommended chain** (confirm on-system with `lv2ls | grep -E 'lsp|gareus|zam'`):

| Plugin | LV2 URI |
|---|---|
| LSP Parametric EQ x16 Stereo | `http://lsp-plug.in/plugins/lv2/para_equalizer_x16_stereo` |
| LSP Parametric EQ x32 Stereo | `http://lsp-plug.in/plugins/lv2/para_equalizer_x32_stereo` |
| LSP Parametric EQ x16 Mid/Side | `http://lsp-plug.in/plugins/lv2/para_equalizer_x16_ms` |
| LSP Multiband Compressor Stereo (x8) | `http://lsp-plug.in/plugins/lv2/mb_compressor_stereo` |
| LSP Limiter Stereo | `http://lsp-plug.in/plugins/lv2/limiter_stereo` |
| x42 Digital Peak Limiter Stereo | `http://gareus.org/oss/lv2/dpl#stereo` |
| x42 Digital Peak Limiter Mono | `http://gareus.org/oss/lv2/dpl#mono` |

## 2.2 Stage-by-stage upgrade map

- **Stage A (prep):** Keep DC correction, 25 Hz HPF, headroom staging. *Optionally* high-pass the **side** channel separately for sub-low cleanup (see Stage D). Already pro-grade.

- **Stage B (EQ):** **Add LSP Parametric EQ** (`para_equalizer_x16_stereo` / `_ms`) alongside (not replacing) the FFmpeg `equalizer`. LSP offers **linear-phase mode** (no phase smear for broad mastering moves) and **mid/side mode** (air on Side, mud control on Mid). Keep FFmpeg `equalizer` as the conditional-disabled fallback. **Add a dynamic-EQ option** (ZamDynamicEQ or ZL Equalizer 2) for problem bands that only misbehave on transients — your dark-top "+2.5 dB @ 11k" static lift could become a *dynamic* lift that only engages when the top is actually recessed, avoiding harshness on already-bright passages.

- **Stage C (glue compression):** Keep `acompressor` for gentle broadband glue if it sounds good (adequate at 1.5–2:1 with light GR). **Add LSP Multiband Compressor** as a new conditional stage for profiles needing band-specific control (e.g. taming sub-bass dynamics independently of the mids). Don't multiband-compress reflexively — single-band glue is often better; make it a *conditional* family option.

- **Stage D (stereo / NEW low-end management):** **Replace the full width-skip with bass-mono via mid/side.** Implement an **elliptical EQ**: high-pass the Side channel below a family-default cutoff (start ~100–120 Hz) with a **linear-phase** filter (LSP linear-phase M/S EQ, or FFmpeg M/S decode → linear-phase HPF on side → re-encode). This keeps the low end mono and tight while *preserving* width above the cutoff — strictly better than killing all width. Keep `extrastereo` architecturally present at m=1.0, conditional-disabled. **Formally encode the correlation-threshold / bass-mono policy as the family default here** (your standing housekeeping item #2).

- **Stage E0 (NEW — soft clip):** Insert **Airwindows ClipOnly2** (or LSP Clipper) *before* the limiter, ceiling ~1–2 dB above the limiter threshold, with limiter input gain reduced by the same amount, so the clipper handles brief sharp peaks and the limiter handles the rest. Single biggest audible loudness-quality upgrade for your genre.

- **Stage E1 (true-peak limit):** **Replace `alimiter` with x42 `dpl.lv2` (true-peak mode, 4× detection) or LSP Limiter (True-Peak mode + ALR, up to 8× oversampling).** Keep your oversample-scaffold approach only if you retain `alimiter` as a fallback. Ceiling −1.0 dBTP for the lossless/club master.

- **Stage E2 (MP3/lossy path limiter):** Keep your separate tighter-ceiling pass (now via dpl/LSP at −1.5 to −2 dBTP) feeding lossy encodes. **Add codec round-trip QC** (Section 2.3).

- **8× oversampling assessment:** Going from 4× to 8× true-peak detection yields *diminishing returns* — 4× already catches the overwhelming majority of inter-sample peaks; the audible benefit of 8× is marginal, mostly for very bright, hot material. LSP's True-Peak mode and x42's 4× key are both sufficient. The clip-before-limit stage matters far more.

## 2.3 Codec-aware QC stage (new verification step)

All FFmpeg + loudness scanners, fully scriptable:
1. Encode the master to **AAC** (use FFmpeg's native `aac` encoder to stay GPL-clean — `libfdk_aac` is not redistributable in GPL builds), **Opus** (`libopus`, ~128–256 kbps to mirror YouTube), and your existing **MP3** (`libmp3lame`).
2. **Decode back to WAV** and **re-measure true peak**. Flag any post-decode TP that exceeds 0 dBFS (or your ceiling).
3. Tools: **`ffmpeg ebur128`** filter (ITU-R BS.1770), **`loudness-scanner`/libebur128**, and **`bs1770gain`** (CLI; BS.1770 / EBU R128 / ATSC A/85 / ReplayGain 2.0; true peak measured at 192 kHz / 4× upsampling). Cross-check FFmpeg's ebur128 against bs1770gain for confidence.

## 2.4 Matchering — use as cross-check, not master path

**Matchering 2.0** (Python, open-source; `matchering-cli` provides `mg_cli.py target reference result` with `-b {16,24,32}`, `--no_limiter`, `--dont_normalize`) matches your target's RMS, frequency response, peak amplitude and stereo width to a reference. It is **not AI** — deterministic DSP matching. **Do NOT make it your master path** (blunt instrument; its built-in limiter is not dpl/LSP-grade). **DO use it as a calibration/reference cross-check:** run your master and a world-class reference through it with `--no_limiter` and inspect the EQ/width delta to *diagnose* where your tonal balance and width differ. Verify determinism with your MD5 method (depends on `libsndfile1`).

## 2.5 Analysis / QC tooling (all CLI/scriptable)

- **Spectrograms:** `ffmpeg ... -lavfi showspectrumpic=s=1920x1080 spectrogram.png` per master — embed in `MASTERING_REPORT.md`. Also SoX `spectrogram`.
- **Tonal-balance delta:** compute long-term average spectrum (FFmpeg `astats`/`showspectrum` or a small Python/librosa script) and plot delta vs a measured reference curve.
- **Loudness/TP/LRA:** `ffmpeg ebur128`, `bs1770gain`, `loudness-scanner`.
- **PSR/PLR:** compute from short-term LUFS + true peak (scriptable from ebur128 short-term output).
- **Deeper frameworks:** **Essentia** (MTG, C++/Python), **librosa**, **aubio**, **sonic-annotator** (CLI batch feature extraction from Sonic Visualiser) — use to build your measured reference library.
- **Phase/correlation:** keep aphasemeter; add per-band correlation logging. **Make the v2 phase-correlation diagnostic canonical in the template** (your standing housekeeping item #1).

## 2.6 Upstream fixes (mix-bus hygiene, vocal prep, gain staging)

- **Fix negative correlation at the mix, not the master.** Audit instrument buses for stereo-wideners/choruses introducing anti-phase content; check mono sources run through stereo-spread plugins; verify sample-pack stems. Use a per-band correlation meter on each bus. Bass and kick mono/centered at source.
- **Gain staging:** keep consistent −6 dB headroom into mastering; ensure the mix bus isn't already limited (leave loudness work to mastering).
- **Vocal prep:** your corrective/conservative three-phase model is correct. Enhancements: dynamic-EQ de-essing (ZamDynamicEQ on the sibilance band) instead of static cuts; keep delivering clean intermediate stems.

---

# DELIVERABLE 3 — Long-Term Roadmap (Monitoring, Translation, QC Standards)

## 3.1 Monitoring & room — your #1 priority (realistic budget)

Principles over products:
- **Treat first reflections and bass.** The biggest error in untreated rooms is bass modes and early reflections. DIY broadband absorbers (10 cm mineral-wool/rockwool panels with an air gap, in fabric frames) at first-reflection points (mirror trick), plus **corner bass traps** (thick floor-to-ceiling rockwool straddling corners). Cheap and transformative.
- **Symmetry.** Speakers and listening position symmetric to side walls, tweeters at ear height, equilateral triangle, speakers off the front wall.
- **Then correct digitally.** Use **DRC-FIR** (Denis Sbragion, GPL) to generate FIR room-correction filters from impulse measurements, and convolve them into your monitor path with **FFmpeg `afir`** (or BruteFIR). Workflow: measure impulse (REW or Sbragion's measuring tool / sweep + `lsconv`), generate filter with DRC, apply via `afir`. Fully scriptable.
- **Caveat:** room correction fixes frequency/time response at the listening spot; it cannot fix a fundamentally bad room — treat first, correct second.

## 3.2 Headphone-based mastering with open-source correction

- **AutoEq** (jaakkopasanen, open-source) generates correction from measured frequency response for 3000+ headphones using the **oratory1990** and other databases, outputting parametric EQ *and* convolution (FIR) filters. Headless:
```
python -m autoeq --input-file="measurements/oratory1990/.../<HP>.csv" \
  --output-dir=out --target="targets/harman_over-ear_2018.csv" \
  --convolution-eq --fs=48000 --bit-depth=32
```
Then convolve the resulting FIR into your monitoring chain with FFmpeg `afir`. Use headphones as a **cross-reference**, not the sole arbiter.
- **Impulcifer** (open-source) creates personalized binaural room impulse responses so headphones simulate a speaker-in-room experience — useful for translation checking on headphones.

## 3.3 Translation testing matrix (scriptable via convolution/filters)

A deterministic FFmpeg-based "translation render" set so every master is auto-auditioned through simulated systems:
- **Phone/laptop speaker:** bandpass ~400 Hz–8 kHz + reduced bass — checks vocal/midrange intelligibility and confirms bass-mono works.
- **Earbuds:** mild HPF + Harman-ish tilt.
- **Car:** low-mid bump + cabin resonance (convolve a car IR if you can source/measure one).
- **Club PA:** **sum to mono below ~120 Hz** check + sub-heavy curve — where your negative-correlation/bass-mono work pays off (mono PA collapse).
- **Mono fold-down:** always render a mono sum and re-measure level loss — large loss = phase problem.
Automate as a script producing labeled WAVs/MP3s + a metrics table per master.

## 3.4 Measured reference library

- Build a library of 10–20 world-class references *in your genre*. For each, log with your scanners: **integrated LUFS, max short-term LUFS, LRA, true peak, PSR/PLR, spectral tilt (octave-band), per-band correlation.** Store as CSV.
- Compute a **target tonal-balance curve** (average spectral tilt) for "Hardcore Pop" — implementable from your octave-band data or Essentia. This becomes your numeric north star, complementing ears.
- Use Matchering (2.4) as a delta-diagnosis tool against these references.

## 3.5 Professional QC checklist standards

Encode into `MASTERING_REPORT.md` as a pass/fail gate:
- **Heads/tails:** clean starts, no truncated transients, appropriate fades.
- **Clicks/pops/dropouts:** scan (spectrogram + null tests).
- **Inter-sample / ISP compliance:** post-encode TP re-check (2.3).
- **DC offset:** verify ≈0 after processing.
- **Fades:** smooth, no zipper artifacts.
- **Sequencing & spacing:** for EP/album, inter-track gaps and level continuity.
- **Loudness/dynamics:** integrated LUFS, TP, LRA, **PSR ≥ 8 in loudest section** logged.
- **Mono compatibility:** mono fold-down level-loss check.
- **Metadata present & correct** (below).

## 3.6 Metadata / delivery standards (open-source)

- **`kid3-cli`** (GPL; `apt install kid3-cli`) — ID3v2.4 for MP3 plus tags for FLAC/Opus/etc., scriptable batch tagging (title/artist/album/year/ISRC/artwork).
- **`bwfmetaedit`** (FADGI/MediaArea, open-source CLI) — embed/validate **BWF `bext`** metadata in WAV including ISRC, and it can store/verify an **MD5 of the audio-data chunk** (`MD5Stored`/`MD5Generated`) — which dovetails perfectly with your determinism discipline.
- **ISRC** embedding for distribution; note WAV tag support is inconsistent across players, so **FLAC is often a better tagged-delivery format than WAV**.
- **DDP for CD** (if ever needed): open-source DDP tooling is limited and sparse — for one-off CD needs, evaluate whether a dedicated tool is worth it vs. delivering 16-bit/44.1 WAV + cue/metadata to a duplicator.

## 3.7 Archival & learning path

- **Archival:** keep 32-bit float masters + session scripts + `MASTERING_REPORT.md` + reference CSVs under version control; store the BWF audio-chunk MD5 in the file itself via bwfmetaedit.
- **Ear training (open/free):** structured EQ ear-training (identify boosted bands), compression detection, and A/B reference discipline. Build PSR/dynamics intuition by correlating what you *hear* with what your meters log on each master.

## 3.8 Staged rollout plan

- **Phase 1 (weeks):** Room treatment + DRC-FIR/`afir` correction; AutoEq headphone cross-ref. (Highest leverage.)
- **Phase 2:** Stand up lv2apply/Carla host path; swap in dpl/LSP limiter; add ClipOnly2 soft-clip stage. Re-verify MD5 determinism.
- **Phase 3:** Add bass-mono/elliptical M/S stage; encode correlation-threshold + bass-mono family policy; make v2 phase diagnostic canonical.
- **Phase 4:** Add LSP multiband + dynamic EQ as conditional stages; codec round-trip QC; spectrogram + tonal-delta in reports.
- **Phase 5:** Build measured reference library + translation matrix + Matchering cross-check; finalize QC gate and metadata automation.

**Benchmarks that would change the plan:** if post-treatment room measurements still show >±6 dB modal swings below 200 Hz, prioritize more bass trapping before any processing work; if your MD5 double-run fails on a new LV2 stage, that stage is disqualified until determinism is proven (or quarantined behind a fixed-seed/offline render); if club-system A/Bs reveal you're consistently quieter than references, push the club deliverable to −8 LUFS while holding PSR ≥ 8.

---

## Caveats & Honest Boundaries

- **Marginal-impact items:** 8× vs 4× oversampling; chasing sub-0.1 dB true-peak precision; exotic saturator stacking. Don't prioritize these over monitoring and the clip→limit stage.
- **Determinism risks to verify:** any dither/RNG stage, Matchering, and any plugin that doesn't report latency cleanly. Use your MD5 double-run on every new stage.
- **lv2apply latency/tail behavior is an inferred limitation** — verify empirically with an impulse test before trusting sample alignment; prefer Carla/jalv where alignment is critical. The exact `dpl.lv2`/LSP control-port symbol strings should be confirmed on-system with `lv2info`.
- **Loudness numbers move.** Platform targets (Spotify/Apple/YouTube/Tidal) are current as of 2026 but change without notice — re-verify before major releases.
- **Open-source AAC:** FFmpeg's native `aac` encoder keeps you GPL-clean; `libfdk_aac` and `qaac` are not open/redistributable — use them only for QC auditioning if at all, never as your distributable encoder.
- **The mix is upstream of everything.** The biggest single quality determinant remains the mix you feed in. Persistent negative correlation is a mix bug; fix it at source.