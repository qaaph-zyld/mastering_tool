"""Executor that renders a Chain DSL through Spotify's `pedalboard`."""

from __future__ import annotations

from pathlib import Path
from typing import List, Optional

import numpy as np

try:
    import pedalboard

    _HAS_PEDALBOARD = True
except ImportError:  # pragma: no cover
    pedalboard = None  # type: ignore
    _HAS_PEDALBOARD = False

from ..schema import Chain, EQBand


def _require_pedalboard() -> None:
    if not _HAS_PEDALBOARD:
        raise RuntimeError(
            "pedalboard is required to render a chain. Install with: "
            "pip install pedalboard"
        )


def _band_to_peak_filter(band: EQBand) -> "pedalboard.PeakFilter":
    return pedalboard.PeakFilter(
        cutoff_frequency_hz=band.freq,
        gain_db=band.gain,
        q=band.q,
    )


def _deesser_to_filters(deesser) -> List["pedalboard.Plugin"]:
    """Approximate a deesser with a narrow band-cut (static de-ess fallback).

    Pedalboard has no dedicated deesser built-in. When a VST3 is not supplied,
    we use a narrow peak cut at the sibilance frequency as a transparent, honest
    fallback. The DSL can later be extended with `vst3_path` to load a real
    deesser plugin.
    """
    q = 1.0 / max(deesser.width_octaves, 0.1)
    # A deesser reduces level; approximate with a small negative gain.
    gain_db = -6.0 * (1.0 - 1.0 / max(deesser.ratio, 1.0))
    return [pedalboard.PeakFilter(cutoff_frequency_hz=deesser.freq, gain_db=gain_db, q=q)]


def build_pedalboard(chain: Chain) -> "pedalboard.Pedalboard":
    """Build a pedalboard Pedalboard from a Chain DSL."""
    _require_pedalboard()
    plugins: List[pedalboard.Plugin] = []

    if not chain.hpf.bypass:
        plugins.append(
            pedalboard.HighpassFilter(cutoff_frequency_hz=chain.hpf.freq)
        )

    if not chain.eq.bypass:
        for band in chain.eq.bands:
            plugins.append(_band_to_peak_filter(band))

    if not chain.deesser.bypass:
        plugins.extend(_deesser_to_filters(chain.deesser))

    if not chain.comp.bypass:
        plugins.append(
            pedalboard.Compressor(
                threshold_db=chain.comp.threshold_db,
                ratio=chain.comp.ratio,
                attack_ms=chain.comp.attack_ms,
                release_ms=chain.comp.release_ms,
            )
        )
        if chain.comp.makeup_db != 0.0:
            plugins.append(pedalboard.Gain(gain_db=chain.comp.makeup_db))

    if not chain.clip.bypass:
        plugins.append(pedalboard.Distortion(drive_db=chain.clip.drive_db))

    if not chain.limit.bypass:
        plugins.append(
            pedalboard.Limiter(
                threshold_db=chain.limit.ceiling_db,
                release_ms=chain.limit.release_ms,
            )
        )

    return pedalboard.Pedalboard(plugins)


def render(
    chain: Chain,
    audio: np.ndarray,
    sample_rate: Optional[float] = None,
) -> np.ndarray:
    """Render a numpy audio buffer through the chain.

    Args:
        chain: Chain DSL to execute.
        audio: (n_samples, n_channels) float32 array. Mono is acceptable as
            shape (n_samples,) or (n_samples, 1).
        sample_rate: Optional override; defaults to chain.sample_rate.

    Returns:
        Processed audio with the same shape as input.
    """
    _require_pedalboard()
    sr = int(sample_rate if sample_rate is not None else chain.sample_rate)
    board = build_pedalboard(chain)
    return board(audio, sr)


def render_file(
    chain: Chain,
    input_path: Path | str,
    output_path: Path | str,
    sample_rate: Optional[float] = None,
) -> None:
    """Load a WAV, render through the chain, and write the result."""
    _require_pedalboard()
    import soundfile as sf

    sr = int(sample_rate if sample_rate is not None else chain.sample_rate)
    audio, file_sr = sf.read(str(input_path), dtype="float32")
    if file_sr != sr:
        raise ValueError(
            f"Input sample rate {file_sr} does not match chain sample rate {sr}"
        )
    out = render(chain, audio, sr)
    sf.write(str(output_path), out, sr)
