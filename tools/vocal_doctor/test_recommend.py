"""Tests for Vocal Doctor recommendation engine — uses synthetic diagnoses,
no real audio or model download required.
"""

from __future__ import annotations

from typing import Any, Dict, List

import pytest

from .recommend import VocalRecommendation, recommend_chain


def _make_diagnosis(
    *,
    sibilant_rms: float = 0.01,
    sibilant_ratio_db: float = -10.0,
    crest_factor_db: float = 15.0,
    short_term_dr_db: float = 15.0,
    tilt_db_per_decade: float = -3.0,
    rt60: float = 0.3,
    integrated_lufs: float = -20.0,
    effects: List[Dict[str, Any]] | None = None,
) -> Dict[str, Any]:
    effects = effects or []
    return {
        "file": "synthetic.wav",
        "duration_seconds": 10.0,
        "voice_detected": True,
        "effects": effects,
        "spectral_profile": {
            "centroid_hz": 1200.0,
            "bandwidth_hz": 1500.0,
            "rolloff_hz": 4000.0,
            "flatness": 0.05,
        },
        "metrics": {
            "loudness": {"integrated_lufs": integrated_lufs, "loudness_range": 8.0},
            "dynamics": {
                "crest_factor_db": crest_factor_db,
                "peak_loudness_ratio_db": 18.0,
                "short_term_dynamic_range_db": short_term_dr_db,
            },
            "sibilance": {
                "sibilant_rms": sibilant_rms,
                "sibilant_ratio_db": sibilant_ratio_db,
            },
            "rt60_seconds": rt60,
            "spectral_tilt_db_per_decade": tilt_db_per_decade,
        },
    }


def test_sibilance_triggers_deesser() -> None:
    diag = _make_diagnosis(sibilant_rms=0.08, sibilant_ratio_db=6.0)
    chain, recs = recommend_chain(diag)
    assert any(r.rule == "SIBILANCE" for r in recs)
    assert chain.deesser.bypass is False
    assert chain.deesser.freq == 6800.0


def test_dark_tilt_adds_high_shelf() -> None:
    diag = _make_diagnosis(tilt_db_per_decade=-5.5)
    chain, recs = recommend_chain(diag)
    assert any(r.rule == "DARK_TILT" for r in recs)
    assert chain.eq.bypass is False
    assert any(b.freq == 10000.0 and b.gain > 0 for b in chain.eq.bands)


def test_bright_tilt_adds_high_cut() -> None:
    diag = _make_diagnosis(tilt_db_per_decade=-0.5)
    chain, recs = recommend_chain(diag)
    assert any(r.rule == "BRIGHT_TILT" for r in recs)
    assert chain.eq.bypass is False
    assert any(b.freq == 8000.0 and b.gain < 0 for b in chain.eq.bands)


def test_low_crest_factor_adds_compressor() -> None:
    diag = _make_diagnosis(crest_factor_db=6.0, short_term_dr_db=5.0)
    chain, recs = recommend_chain(diag)
    assert any(r.rule == "COMPRESSION" for r in recs)
    assert chain.comp.bypass is False
    assert chain.comp.threshold_db == -18.0


def test_loud_vocal_adds_limiter() -> None:
    diag = _make_diagnosis(integrated_lufs=-10.0)
    chain, recs = recommend_chain(diag)
    assert any(r.rule == "LIMITER" for r in recs)
    assert chain.limit.bypass is False
    assert chain.limit.ceiling_db == -1.0


def test_no_hpf_detected_adds_hpf() -> None:
    diag = _make_diagnosis()
    chain, recs = recommend_chain(diag)
    assert any(r.rule == "HPF" for r in recs)
    assert chain.hpf.bypass is False
    assert chain.hpf.freq == 80.0


def test_reverb_long_rt60_flagged() -> None:
    diag = _make_diagnosis(rt60=1.2)
    chain, recs = recommend_chain(diag)
    assert any(r.rule == "REVERB" for r in recs)


def test_recommendations_sorted_by_confidence() -> None:
    diag = _make_diagnosis(
        sibilant_rms=0.08,
        sibilant_ratio_db=6.0,
        crest_factor_db=6.0,
        short_term_dr_db=5.0,
    )
    _, recs = recommend_chain(diag)
    confidences = [r.confidence for r in recs]
    assert confidences == sorted(confidences, reverse=True)


def test_vocal_recommendation_dataclass() -> None:
    r = VocalRecommendation(
        rule="TEST", problem="test problem", confidence=0.5, evidence=["x"]
    )
    assert r.__dict__["rule"] == "TEST"
