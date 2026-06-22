"""Rule-based recommendation engine that maps a vocal diagnosis to a Chain DSL.

Every recommendation exposes:
- what rule fired
- what evidence triggered it
- the concrete DSL change it proposes
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

from mastering_tool.tools.chain_dsl.schema import Chain, Compressor, Deesser, EQ, EQBand, HPF, Limiter

from .diagnose import diagnose_vocal


@dataclass
class VocalRecommendation:
    rule: str
    problem: str
    confidence: float
    evidence: List[str] = field(default_factory=list)
    chain_action: str = ""  # Human-readable description of the DSL change


def _find_effect(effects: List[Dict[str, Any]], name: str) -> Optional[Dict[str, Any]]:
    for e in effects:
        if e.get("effect") == name:
            return e
    return None


def _db(x: float) -> str:
    return f"{x:.1f} dB"


def recommend_chain(diagnosis: Dict[str, Any]) -> tuple[Chain, List[VocalRecommendation]]:
    """Map a vocal diagnosis to a ranked chain + transparent recommendations."""
    recommendations: List[VocalRecommendation] = []
    chain = Chain(sample_rate=48000.0)
    metrics = diagnosis.get("metrics", {})
    effects = diagnosis.get("effects", [])
    spectral = diagnosis.get("spectral_profile", {})

    loudness = metrics.get("loudness", {})
    dynamics = metrics.get("dynamics", {})
    sibilance = metrics.get("sibilance", {})
    rt60 = metrics.get("rt60_seconds", 0.0)
    tilt = metrics.get("spectral_tilt_db_per_decade", 0.0)

    comp_effect = _find_effect(effects, "compression") or {}
    comp_params = comp_effect.get("params", {})
    eq_effect = _find_effect(effects, "eq_filtering") or {}
    eq_params = eq_effect.get("params", {})
    deess_effect = _find_effect(effects, "de_essing") or {}
    deess_params = deess_effect.get("params", {})
    reverb_effect = _find_effect(effects, "reverb") or {}
    reverb_params = reverb_effect.get("params", {})
    dist_effect = _find_effect(effects, "distortion") or {}
    dist_params = dist_effect.get("params", {})

    # ------------------------------------------------------------------
    # Rule 1: Sibilance — deesser
    # ------------------------------------------------------------------
    sib_rms = sibilance.get("sibilant_rms", 0.0)
    sib_ratio_db = sibilance.get("sibilant_ratio_db", -999.0)
    # If sibilant band is hot relative to surroundings, or detector already flagged it
    if sib_rms > 0.05 or sib_ratio_db > 3.0 or deess_effect.get("confidence", 0.0) > 0.5:
        evidence = [
            f"Sibilant band RMS: {sib_rms:.4f}",
            f"Sibilant ratio vs surrounding: {_db(sib_ratio_db)}",
        ]
        if deess_effect.get("confidence", 0.0) > 0.5:
            evidence.append(
                f"De-essing detector confidence: {deess_effect['confidence']:.0%}"
            )
        chain.deesser = Deesser(
            freq=6800.0,
            threshold_db=-28.0,
            ratio=4.0,
            width_octaves=0.5,
            bypass=False,
        )
        recommendations.append(
            VocalRecommendation(
                rule="SIBILANCE",
                problem="Excessive sibilance (S/T energy) detected",
                confidence=min(0.95, 0.5 + max(sib_ratio_db, 0.0) * 0.1),
                evidence=evidence,
                chain_action="Insert de-esser at 6.8 kHz, threshold -28 dB, ratio 4:1",
            )
        )

    # ------------------------------------------------------------------
    # Rule 2: Harsh top / tilt too steep
    # ------------------------------------------------------------------
    if tilt < -4.0:
        evidence = [f"Spectral tilt: {tilt:.1f} dB/decade (too dark/harsh)"]
        # Add a gentle high-shelf lift, not a sharp peak
        chain.eq.bands.append(EQBand(freq=10000.0, gain=1.5, q=0.7))
        chain.eq.bypass = False
        recommendations.append(
            VocalRecommendation(
                rule="DARK_TILT",
                problem="Spectrum rolls off too fast in the top end",
                confidence=min(0.9, abs(tilt) / 6.0),
                evidence=evidence,
                chain_action="Add gentle high-shelf lift (+1.5 dB at 10 kHz, Q 0.7)",
            )
        )
    elif tilt > -1.5:
        evidence = [f"Spectral tilt: {tilt:.1f} dB/decade (too bright)"]
        chain.eq.bands.append(EQBand(freq=8000.0, gain=-1.5, q=0.7))
        chain.eq.bypass = False
        recommendations.append(
            VocalRecommendation(
                rule="BRIGHT_TILT",
                problem="Top end is too prominent relative to lows",
                confidence=min(0.85, tilt / 2.0),
                evidence=evidence,
                chain_action="Gentle high-shelf cut (-1.5 dB at 8 kHz, Q 0.7)",
            )
        )

    # ------------------------------------------------------------------
    # Rule 3: Presence / boxiness
    # ------------------------------------------------------------------
    presence = eq_params.get("presence_boost_db", 0.0)
    if presence < 1.0:
        evidence = [f"No significant presence boost detected ({_db(presence)} in 2-5 kHz)"]
        chain.eq.bands.append(EQBand(freq=3500.0, gain=1.5, q=1.2))
        chain.eq.bypass = False
        recommendations.append(
            VocalRecommendation(
                rule="PRESENCE",
                problem="Vocal lacks forward presence in the mix",
                confidence=0.7,
                evidence=evidence,
                chain_action="Add presence peak (+1.5 dB at 3.5 kHz, Q 1.2)",
            )
        )

    # ------------------------------------------------------------------
    # Rule 4: Low-end buildup / missing HPF
    # ------------------------------------------------------------------
    if eq_params.get("high_pass_detected") is not True:
        evidence = ["No high-pass filter detected — low-end may be muddy"]
        chain.hpf = HPF(freq=80.0, slope=12, bypass=False)
        recommendations.append(
            VocalRecommendation(
                rule="HPF",
                problem="Low-frequency content not controlled",
                confidence=0.75,
                evidence=evidence,
                chain_action="Insert HPF at 80 Hz, 12 dB/octave",
            )
        )

    # ------------------------------------------------------------------
    # Rule 5: Compression / dynamics
    # ------------------------------------------------------------------
    crest = dynamics.get("crest_factor_db", 20.0)
    st_dr = dynamics.get("short_term_dynamic_range_db", 20.0)
    existing_ratio = comp_params.get("estimated_ratio", "")
    if crest < 8 or st_dr < 6 or "8:1" in existing_ratio or "4:1" in existing_ratio:
        evidence = [
            f"Crest factor: {_db(crest)}",
            f"Short-term dynamic range: {_db(st_dr)}",
        ]
        if existing_ratio:
            evidence.append(f"Detected compression: {existing_ratio}")
        chain.comp = Compressor(
            threshold_db=-18.0,
            ratio=3.0,
            attack_ms=5.0,
            release_ms=80.0,
            bypass=False,
        )
        recommendations.append(
            VocalRecommendation(
                rule="COMPRESSION",
                problem="Vocal is either already heavily compressed or needs control",
                confidence=min(0.9, 1.0 - crest / 15.0),
                evidence=evidence,
                chain_action="Insert compressor: threshold -18 dB, ratio 3:1, attack 5 ms, release 80 ms",
            )
        )

    # ------------------------------------------------------------------
    # Rule 6: Limiter / headroom safety
    # ------------------------------------------------------------------
    integrated = loudness.get("integrated_lufs")
    if integrated is not None and integrated > -12.0 or dist_effect.get("confidence", 0.0) > 0.5:
        evidence = []
        if integrated is not None:
            evidence.append(f"Integrated loudness: {_db(integrated)} LUFS")
        if dist_effect.get("confidence", 0.0) > 0.5:
            evidence.append(
                f"Distortion/clipping detector confidence: {dist_effect['confidence']:.0%}"
            )
        chain.limit = Limiter(ceiling_db=-1.0, lookahead_ms=20.0, bypass=False)
        recommendations.append(
            VocalRecommendation(
                rule="LIMITER",
                problem="Vocal is loud or shows clipping — add safety limiter",
                confidence=0.8,
                evidence=evidence,
                chain_action="Insert safety limiter at -1.0 dBFS ceiling",
            )
        )

    # ------------------------------------------------------------------
    # Rule 7: Reverb / room
    # ------------------------------------------------------------------
    rt60_est = reverb_params.get("estimated_rt60_seconds", rt60)
    if rt60_est and rt60_est > 0.8:
        evidence = [f"Estimated RT60: {rt60_est:.2f}s"]
        recommendations.append(
            VocalRecommendation(
                rule="REVERB",
                problem="Reverb tail is long / roomy",
                confidence=min(0.85, rt60_est / 2.0),
                evidence=evidence,
                chain_action="Consider de-reverb (not implemented in built-in chain) — use a VST3 or manual editing",
            )
        )

    recommendations.sort(key=lambda r: r.confidence, reverse=True)
    return chain, recommendations


def diagnose_and_recommend(path: Path | str) -> Dict[str, Any]:
    """Convenience: diagnose a vocal file and return chain + recommendations."""
    diagnosis = diagnose_vocal(path)
    chain, recommendations = recommend_chain(diagnosis)
    return {
        "diagnosis": diagnosis,
        "chain": chain.to_dict(),
        "recommendations": [r.__dict__ for r in recommendations],
    }
