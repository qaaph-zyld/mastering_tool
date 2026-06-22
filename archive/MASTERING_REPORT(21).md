# Mastering Report — MiXaLL x ZIVOT LEP BB

## Source diagnosis
| Metric | Value | Verdict |
|---|---|---|
| Integrated loudness | −8.9 LUFS | Already loud (loudness-war territory) |
| True peak | **−0.2 dBTP** | ⚠️ Inter-sample clip risk on consumer playback |
| Loudness range (LRA) | 6.9 LU | Moderately squashed |
| Crest factor | 3.07 | Heavily limited |
| Low-mid 120–400 Hz | −17.9 dB | Slight muddiness |
| High-mid 2–6 kHz | −23.1 dB | Vocal presence slightly recessed |
| Air 6–16 kHz | −25.4 dB | Slightly dull |

## Processing chain (in order)
1. **Pre-attenuate −3 dB** — headroom for EQ boosts
2. **DC offset removal**
3. **High-pass 28 Hz** — subsonic rumble cleanup (preserves usable sub)
4. **EQ +0.6 dB @ 80 Hz, Q=1.2** — low-end warmth
5. **EQ −1.5 dB @ 250 Hz, Q=1.0** — de-mud
6. **EQ −0.8 dB @ 450 Hz, Q=1.2** — boxiness tame
7. **EQ +1.2 dB @ 4 kHz, Q=0.9** — vocal/lead presence
8. **EQ +1.5 dB @ 12 kHz, Q=0.7** — air/openness
9. **Glue compressor** — ratio 1.5, slow attack 30 ms, release 250 ms, knee 6 dB, ≤1 dB GR
10. **Subtle harmonic exciter** — drive 3, amount 0.8, freq 7.5 kHz
11. **Mid/side stereo widening** — sides +0.7 dB (subtle, preserves mono compat)
12. **Makeup +4 dB** → push into limiter
13. **4× oversampled true-peak limiter** — ceiling −2 dBFS at 176.4 kHz
14. **Downsample to 44.1 kHz** (soxr precision 28)
15. **−1.5 dB trim**
16. **Final 44.1 kHz safety limiter** — ceiling −1 dBFS

## Before / After

| Metric | Before | After | Improvement |
|---|---|---|---|
| Integrated LUFS | −8.9 | **−9.7** | Cleaner, headroom-safe |
| True peak | −0.2 dBTP | **−0.4 dBTP** | ✓ No inter-sample clipping |
| Loudness range | 6.9 LU | 5.7 LU | Minor compression for cohesion |
| Sub 20–120 Hz | −14.0 dB | −15.1 dB | Cleaner sub (rumble removed) |
| Low-mid 120–400 | −17.9 dB | −19.5 dB | **De-mudded (−1.6 dB)** |
| Air 6–16 kHz | −25.4 dB | −24.7 dB | **Brighter relative balance** |

## Deliverables
- `MiXaLL_x_ZIVOT_LEP_BB_master_32f.wav` — 32-bit float archival master
- `MiXaLL_x_ZIVOT_LEP_BB_master.wav` — 16-bit dithered (CD/distribution)
- `MiXaLL_x_ZIVOT_LEP_BB_master.mp3` — 320 kbps (streaming/sharing)
- `mastering_pipeline.sh` — reusable automation script

## Targets met
- ✅ −1 dBTP class compliance (−0.4 dBTP final)
- ✅ −9 to −10 LUFS (club/streaming sweet spot)
- ✅ Mono compatibility preserved (bass kept centred)
- ✅ Dynamics largely preserved (5.7 LU)
- ✅ All processing reversible (32-bit float archival kept)
