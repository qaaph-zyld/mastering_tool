# PREMASTER ACCEPTANCE SPEC
## Gates a premaster must pass before mastering begins
### v1.0 — 2026-06-12 · derived from Cunami–Violet commercial benchmark

This spec exists because the largest measurable gap between the Hardcore-Pop
family and commercial releases is **not** in the mastering chain — it is in the
material arriving at mastering. Two findings from the Violet benchmark force
this document into existence:

1. **Phase coherence is the genre standard.** A famous in-genre release measures
   full-band correlation min −0.058 and <120 Hz mean +0.80. Our family runs
   chronic −0.36…−0.90 minima. Mastering bass-mono can *attenuate* this but
   never resolve it — it is a mix property.
2. **Micro-dynamics cannot be created downstream.** Our competitive-profile
   render matched the reference's loudness (−8.0 LUFS), short-term level and
   density spread with far cleaner peaks (2 clipped samples vs ~19k, −0.8 dBTP
   vs +1.1), yet landed PSR 6.1 vs the reference's 7.9 — because the test source
   arrived already crushed. The reference earned 7.9 from a *dynamic* mix.
   **Therefore the premaster must arrive with dynamics intact.**

A premaster that fails these gates is returned to the mix with the specific
failing register/metric. This is the same discipline as the vocal-prep phase:
fix it upstream, conservatively, before the irreversible loudness stage.

---

## Gates

| # | Gate | PASS | FLAG (proceed + remediate, log it) | FAIL (return to mix) | Measured by |
|---|---|---|---|---|---|
| 1 | Full-band corr min | ≥ −0.20 | −0.50 … −0.20 | < −0.50 | `mix_phase_gate.sh` |
| 2 | <120 Hz corr mean | ≥ +0.70 | +0.40 … +0.70 | < +0.40 | `mix_phase_gate.sh` |
| 3 | Sample peak headroom | ≤ −3.0 dBFS | −3.0 … 0 dBFS | ≥ 0 dBFS (clipped) | `mix_phase_gate.sh` |
| 4 | Crest factor | ≥ 12 dB | 9 … 12 dB | < 9 dB | astats Peak−RMS |
| 5 | PSR (TP − max ST) of premaster | ≥ 11 dB | 8 … 11 dB | < 8 dB | `qc_metrics_ext.sh` |
| 6 | DC offset | \|DC\| < 0.001 | 0.001 … 0.005 | ≥ 0.005 | astats DC offset |
| 7 | Declared provenance | sr/bits stated, lossless ancestry | unknown ancestry | lossy ancestry undisclosed | manual |

**Why gates 4–5 (dynamics) are strict:** the competitive (−8 LUFS) profile only
preserves PSR ≥ 7.5 at the master if the premaster arrives with PSR ≥ ~11 and
crest ≥ ~12. Each dB of density spent in the mix is a dB the master cannot
recover. The default −10 LUFS profile is more forgiving but the principle holds.

**Why gate 2 is set at +0.70:** that is the *reference's* low-band mean. We are
not asking for perfection — we are asking the mix to reach the demonstrated
commercial bar for bass mono-coherence.

---

## Per-register routing on FLAG/FAIL

`mix_phase_gate.sh` reports the worst-correlated register (sub / low-mid / mid /
high). Route the fix to that register specifically:

- **sub / low-mid anti-phase** → mono-sum below ~120 Hz at the mix bus; check for
  stereo-widened or out-of-phase bass/sub/808 elements; verify no anti-phase
  stereo-spread preset on low-register synths.
- **mid anti-phase** → usually a widened vocal double, stereo reverb return, or
  Haas-delayed element folding against its dry signal. Narrow or mono the return.
- **high anti-phase** → stereo exciter / chorus on hats/air; reduce width or
  high-pass the widening.

---

## Mix-stage rules (extends the vocal-prep model into the mix phase)

These are the upstream practices that make a premaster pass gates 1–2 by
construction rather than by remediation:

1. **Mono bass synthesis below ~120 Hz** on the mix bus (or per low-register stem).
2. **No anti-phase stereo-spread presets** on bass, sub, 808, kick.
3. **Per-stem correlation check before bounce** — run `mix_phase_gate.sh` on each
   stem group, not just the final 2-track.
4. **Width via mid/side EQ or true stereo sources**, never via polarity-inverting
   tricks that collapse in mono.
5. **Leave dynamics in.** Do not bus-limit the mix to −8 before mastering; deliver
   ≥ −3 dBFS headroom, crest ≥ 12 dB. Loudness is the master's job.

---

## Workflow

```
premaster.wav
   │
   ├─ bash mix_phase_gate.sh premaster.wav        # gates 1–3
   ├─ bash qc_metrics_ext.sh premaster.wav        # gates 4–6 (PSR/crest/DC)
   │
   ├─ all PASS  → clear to master (any profile)
   ├─ any FLAG  → master with documented remediation (bass-mono on; note in report)
   └─ any FAIL  → return to mix with the failing register/metric; do not master
```

Every mastering report records the gate verdict for the source it was built from.
A FLAG that recurs across a whole family (as our negative-correlation does) is a
**standing mix-process defect**, escalated to the DAW session, not re-patched per
track at mastering.
