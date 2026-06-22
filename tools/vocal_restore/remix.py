#!/usr/bin/env python3
"""Re-mix restored vocal with instrumental.

Handles gain matching (none / LUFS / RMS) and optional breath-bed insertion.

Usage:
    python remix.py --vocal vocal_restored.wav \
                    --instrumental instrumental.wav \
                    --output restored_full_mix.wav \
                    --gain-match lufs \
                    --breath-bed roomtone.wav
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Optional, Tuple

import numpy as np
import soundfile as sf


def _lufs_integrated(audio: np.ndarray, sr: int) -> float:
    """Approximate EBU R-128 integrated loudness (simplified, no gating)."""
    # Mean square per channel, then mean across channels
    ms = np.mean(audio**2)
    lufs = -10 * np.log10(ms) - 0.691 if ms > 0 else -70.0
    return lufs


def _rms(audio: np.ndarray) -> float:
    return float(np.sqrt(np.mean(audio**2)))


def _match_gain(
    vocal: np.ndarray,
    inst: np.ndarray,
    mode: str,
) -> Tuple[np.ndarray, np.ndarray]:
    """Return gain-matched vocal and instrumental."""
    if mode == "none":
        return vocal, inst

    if mode == "lufs":
        v_lufs = _lufs_integrated(vocal, 48000)  # sr irrelevant for simplified calc
        i_lufs = _lufs_integrated(inst, 48000)
        delta = i_lufs - v_lufs
        gain = 10 ** (delta / 20)
        return vocal * gain, inst

    if mode == "rms":
        v_rms = _rms(vocal)
        i_rms = _rms(inst)
        if v_rms > 0 and i_rms > 0:
            gain = i_rms / v_rms
            return vocal * gain, inst
        return vocal, inst

    raise ValueError(f"Unknown gain-match mode: {mode}")


def remix(
    vocal_path: Path,
    instrumental_path: Path,
    output_path: Path,
    gain_match: str = "none",
    breath_bed_path: Optional[Path] = None,
    breath_bed_gain_db: float = -30.0,
) -> Path:
    """Mix restored vocal with instrumental.

    Args:
        vocal_path: Restored vocal stem.
        instrumental_path: Original instrumental stem.
        output_path: Output full mix path.
        gain_match: 'none', 'lufs', or 'rms'.
        breath_bed_path: Optional room-tone / breath-bed file.
        breath_bed_gain_db: Gain of the breath bed in dB (default -30).

    Returns:
        Path to written output file.
    """
    vocal, sr = sf.read(str(vocal_path), dtype="float32")
    inst, sr2 = sf.read(str(instrumental_path), dtype="float32")

    if sr != sr2:
        raise ValueError(
            f"Sample rate mismatch: vocal={sr} instrumental={sr2}"
        )

    # Normalise to stereo
    if vocal.ndim == 1:
        vocal = np.stack([vocal, vocal], axis=1)
    if inst.ndim == 1:
        inst = np.stack([inst, inst], axis=1)

    if vocal.shape != inst.shape:
        # Truncate to shortest
        n = min(vocal.shape[0], inst.shape[0])
        vocal = vocal[:n]
        inst = inst[:n]

    # Gain match
    vocal, inst = _match_gain(vocal, inst, gain_match)

    # Breath bed
    if breath_bed_path and breath_bed_path.exists():
        bed, sr_bed = sf.read(str(breath_bed_path), dtype="float32")
        if sr_bed != sr:
            import librosa

            if bed.ndim == 1:
                bed = librosa.resample(bed, orig_sr=sr_bed, target_sr=sr)
                bed = np.stack([bed, bed], axis=1)
            else:
                bed = librosa.resample(bed.T, orig_sr=sr_bed, target_sr=sr).T
        # Loop or truncate to match length
        if bed.shape[0] < vocal.shape[0]:
            repeats = int(np.ceil(vocal.shape[0] / bed.shape[0]))
            bed = np.tile(bed, (repeats, 1))[: vocal.shape[0]]
        else:
            bed = bed[: vocal.shape[0]]

        bed_gain = 10 ** (breath_bed_gain_db / 20)
        vocal = vocal + bed * bed_gain

    # Sum
    mix = vocal + inst

    # Soft-clip guard (just in case gain-match pushed peaks over 1.0)
    peak = np.max(np.abs(mix))
    if peak > 1.0:
        print(
            f"[remix] warning: peak {peak:.3f} > 1.0; attenuating by {20 * np.log10(peak):.2f} dB",
            file=sys.stderr,
        )
        mix = mix / peak

    sf.write(str(output_path), mix, sr, subtype="FLOAT")
    print(f"[remix] wrote {output_path}  ({mix.shape[0] / sr:.2f}s)", file=sys.stderr)
    return output_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Re-mix restored vocal + instrumental")
    parser.add_argument("--vocal", type=Path, required=True)
    parser.add_argument("--instrumental", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--gain-match",
        choices=["none", "lufs", "rms"],
        default="none",
        help="Gain-match strategy for the vocal against the instrumental",
    )
    parser.add_argument(
        "--breath-bed",
        type=Path,
        default=None,
        help="Room-tone / breath-bed file to mix under vocal",
    )
    parser.add_argument(
        "--breath-bed-gain",
        type=float,
        default=-30.0,
        help="Breath-bed gain in dB (default: -30)",
    )
    args = parser.parse_args(argv)

    remix(
        vocal_path=args.vocal,
        instrumental_path=args.instrumental,
        output_path=args.output,
        gain_match=args.gain_match,
        breath_bed_path=args.breath_bed,
        breath_bed_gain_db=args.breath_bed_gain,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
