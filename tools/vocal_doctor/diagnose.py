"""Vocal diagnosis wrapper — combines the umbrella's voice-effects detector
with additional lightweight metrics (LUFS, dynamics, sibilance, RT60, tilt)."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict

import librosa

from toolshop.voice_effects_adapter import analyze_voice

from .metrics import (
    dynamic_metrics,
    estimate_rt60,
    loudness_metrics,
    sibilance_metrics,
    spectral_tilt,
)


def diagnose_vocal(path: Path | str, sr: int = 22050) -> Dict[str, Any]:
    """Analyze a vocal stem and return a diagnostic report.

    Args:
        path: Path to the vocal audio file.
        sr: Analysis sample rate. 22050 is sufficient for sibilance and dynamics.

    Returns:
        Dict containing effects, spectral profile, and numerical metrics.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Audio file not found: {path}")

    # Run the existing 12-detector analysis (loads at 22050 internally).
    effects_result = analyze_voice(path)

    # Load once for our additional metrics at the same rate.
    y, sr_out = librosa.load(str(path), sr=sr, mono=True)

    return {
        "file": str(path),
        "duration_seconds": effects_result["duration_seconds"],
        "voice_detected": effects_result["voice_detected"],
        "fundamental_frequency_hz": effects_result.get("fundamental_frequency_hz"),
        "effects": effects_result["effects_detected"],
        "spectral_profile": effects_result["spectral_profile"],
        "metrics": {
            "loudness": loudness_metrics(y, sr_out),
            "dynamics": dynamic_metrics(y, sr_out),
            "sibilance": sibilance_metrics(y, sr_out),
            "rt60_seconds": estimate_rt60(y, sr_out),
            "spectral_tilt_db_per_decade": spectral_tilt(y, sr_out),
        },
    }
