"""Lightweight audio metrics for Vocal Doctor.

Adapted from track_inventory/track_reverse_engineering/wav_reverse_engineer/
audio_analyzer/effects_analyzer.py (MIT). These metrics use only librosa,
numpy, scipy, and pyloudnorm.
"""

from __future__ import annotations

from typing import Dict, Optional

import librosa
import numpy as np

try:
    import pyloudnorm as pyln

    _HAS_PYLOUDNORM = True
except ImportError:  # pragma: no cover
    pyln = None  # type: ignore
    _HAS_PYLOUDNORM = False


def _short_term_rms(x: np.ndarray, frame_samples: int, hop_samples: int) -> np.ndarray:
    if len(x) < frame_samples:
        return np.array([])
    frames = []
    for i in range(0, len(x) - frame_samples + 1, hop_samples):
        frames.append(np.sqrt(np.mean(x[i : i + frame_samples] ** 2)))
    return np.asarray(frames)


def loudness_metrics(audio: np.ndarray, sr: int) -> Dict[str, Optional[float]]:
    """Integrated LUFS and loudness range (LRA)."""
    if not _HAS_PYLOUDNORM or pyln is None:
        return {"integrated_lufs": None, "loudness_range": None}
    y = np.asarray(audio, dtype=np.float64)
    meter = pyln.Meter(sr)
    integrated = float(meter.integrated_loudness(y))
    lra: Optional[float] = None
    if hasattr(meter, "loudness_range"):
        try:
            lra = float(meter.loudness_range(y))
        except Exception:
            pass
    if lra is None:
        try:
            from pyloudnorm import loudness as _pln_loud

            if hasattr(_pln_loud, "loudness_range"):
                lra = float(_pln_loud.loudness_range(y, sr))
            elif hasattr(_pln_loud, "lra"):
                lra = float(_pln_loud.lra(y, sr))
        except Exception:
            pass
    if lra is None:
        win = int(3.0 * sr)
        hop = int(1.0 * sr)
        st_rms = _short_term_rms(y, win, hop)
        if st_rms.size > 0:
            st_db = 20.0 * np.log10(st_rms + 1e-12)
            lra = max(float(np.percentile(st_db, 95) - np.percentile(st_db, 10)), 0.0)
        else:
            lra = 0.0
    return {"integrated_lufs": integrated, "loudness_range": lra}


def estimate_rt60(audio: np.ndarray, sr: int) -> float:
    """Estimate RT60 from the energy decay curve (EDC)."""
    y = librosa.util.normalize(audio)
    energy = y ** 2
    edc = np.flip(np.cumsum(np.flip(energy)))
    edc_db = 10 * np.log10(edc + 1e-12)
    edc_db = edc_db - np.max(edc_db)
    idx_start = np.argmax(edc_db <= -5)
    idx_end = np.argmax(edc_db <= -35)
    if idx_start == 0 or idx_end == 0 or idx_end <= idx_start:
        return 0.0
    x = np.arange(idx_start, idx_end) / sr
    y_db = edc_db[idx_start:idx_end]
    A = np.vstack([x, np.ones_like(x)]).T
    m, _ = np.linalg.lstsq(A, y_db, rcond=None)[0]
    if m == 0:
        return 0.0
    rt60 = -60.0 / m
    return float(max(rt60, 0.0))


def spectral_tilt(audio: np.ndarray, sr: int) -> float:
    """Slope of the long-term average spectrum in dB per decade."""
    S = np.abs(librosa.stft(audio, n_fft=4096, hop_length=1024))
    mag = np.mean(S, axis=1) + 1e-12
    freqs = librosa.fft_frequencies(sr=sr, n_fft=4096)
    x = np.log10(freqs[1:])
    y = 20 * np.log10(mag[1:])
    A = np.vstack([x, np.ones_like(x)]).T
    m, _ = np.linalg.lstsq(A, y, rcond=None)[0]
    return float(m)


def sibilance_metrics(audio: np.ndarray, sr: int) -> Dict[str, float]:
    """Energy in the sibilant band (4-9 kHz) relative to the surrounding band."""
    S = np.abs(librosa.stft(audio))
    freqs = librosa.fft_frequencies(sr=sr)
    power = np.mean(S ** 2, axis=1)
    sib_mask = (freqs > 4000) & (freqs < 9000)
    below_mask = (freqs > 2000) & (freqs < 4000)
    above_mask = (freqs > 9000) & (freqs < 11000)
    sib_power = float(np.sum(power[sib_mask]))
    surrounding = float(np.sum(power[below_mask]) + np.sum(power[above_mask]))
    surrounding = max(surrounding, 1e-12)
    sib_rms = float(np.sqrt(sib_power / max(1, np.sum(sib_mask))))
    sib_ratio_db = float(10.0 * np.log10(sib_power / surrounding + 1e-12))
    return {"sibilant_rms": sib_rms, "sibilant_ratio_db": sib_ratio_db}


def dynamic_metrics(audio: np.ndarray, sr: int) -> Dict[str, float]:
    """Crest factor, peak-to-loudness ratio, and short-term dynamic range."""
    peak = float(np.max(np.abs(audio)))
    rms = float(np.sqrt(np.mean(audio ** 2)))
    crest_factor_db = float(20.0 * np.log10(peak / max(rms, 1e-12)))

    # Short-term RMS (100ms windows) for PSR-like metric
    frame = int(0.1 * sr)
    hop = int(0.05 * sr)
    st_rms = _short_term_rms(audio, frame, hop)
    st_rms_db = 20.0 * np.log10(st_rms + 1e-12)
    plr = float(20.0 * np.log10(peak / max(float(np.mean(st_rms)), 1e-12)))
    short_term_dr = float(
        np.percentile(st_rms_db, 95) - np.percentile(st_rms_db, 5)
    ) if st_rms.size > 0 else 0.0

    return {
        "crest_factor_db": crest_factor_db,
        "peak_loudness_ratio_db": plr,
        "short_term_dynamic_range_db": short_term_dr,
    }
