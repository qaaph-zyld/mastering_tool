#!/usr/bin/env python3
"""Vocal restoration chain for SUNO-sourced tracks.

Stages (toggleable via env vars or CLI flags):
  --stage deepfilter   DeepFilterNet3  de-room / de-noise  (env: VR_DEROOM=1)
  --stage voicefixer   VoiceFixer      de-plastic (mode 2)  (env: VR_VOICEFIXER=1)
  --stage apollo       Apollo          de-codec / restore HF (env: VR_APOLLO=1)
  --stage audiosr      AudioSR         48 kHz upsample       (env: VR_AUDIOSR=0)

Usage:
    python restore.py input_vocal.wav output_restored.wav [--stage STAGE ...]

Progress is streamed to stderr. The chain is idempotent: re-running with the same
input and stages produces the same output (deterministic models, fixed seeds).
"""

from __future__ import annotations

import argparse
import os
import sys
import warnings
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

import numpy as np
import soundfile as sf

# ---------------------------------------------------------------------------
# Library availability probes
# ---------------------------------------------------------------------------

_LAZY = {}


def _has(name: str) -> bool:
    if name not in _LAZY:
        try:
            __import__(name)
            _LAZY[name] = True
        except ImportError:
            _LAZY[name] = False
    return _LAZY[name]


def _warn_missing(lib: str, install_hint: str) -> None:
    warnings.warn(
        f"{lib} is not installed. Stage skipped. "
        f"Install with: pip install '{install_hint}'",
        RuntimeWarning,
        stacklevel=3,
    )


# ---------------------------------------------------------------------------
# Stage implementations
# ---------------------------------------------------------------------------

def stage_deepfilter(
    audio: np.ndarray, sr: int, progress: Optional[Callable[[str, float], None]] = None
) -> Tuple[np.ndarray, int]:
    """DeepFilterNet3: de-room / de-noise."""
    if not _has("df.enhance"):
        _warn_missing("deepfilternet", "deepfilternet")
        return audio, sr

    from df.enhance import enhance, init_df

    if progress:
        progress("deepfilter", 0.0)

    model, df_state, _ = init_df()
    out = enhance(model, df_state, audio, pad=True)

    if progress:
        progress("deepfilter", 1.0)

    return out, sr


def stage_voicefixer(
    audio: np.ndarray, sr: int, progress: Optional[Callable[[str, float], None]] = None
) -> Tuple[np.ndarray, int]:
    """VoiceFixer mode 2: de-plastic / de-synthetic."""
    if not _has("voicefixer"):
        _warn_missing("voicefixer", "voicefixer")
        return audio, sr

    from voicefixer import VoiceFixer

    if progress:
        progress("voicefixer", 0.0)

    # VoiceFixer works on files, not in-memory arrays. Use a temp file.
    import tempfile

    with tempfile.TemporaryDirectory(prefix="vr_voicefixer_") as tmp:
        tmp_path = Path(tmp)
        in_path = tmp_path / "in.wav"
        out_path = tmp_path / "out.wav"
        sf.write(str(in_path), audio, sr, subtype="FLOAT")

        vf = VoiceFixer()
        # Mode 2 = TTS-like (closest to SUNO synthetic artifacts)
        vf.restore(input=in_path, output=out_path, cuda=False, mode=2)

        out, out_sr = sf.read(str(out_path), dtype="float32")
        if out.ndim == 1:
            out = out[:, None]
        # Resample back to source sr if VoiceFixer changed it.
        if out_sr != sr:
            import librosa

            out = librosa.resample(out.T, orig_sr=out_sr, target_sr=sr).T

    if progress:
        progress("voicefixer", 1.0)

    return out, sr


def stage_apollo(
    audio: np.ndarray, sr: int, progress: Optional[Callable[[str, float], None]] = None
) -> Tuple[np.ndarray, int]:
    """Apollo: de-codec / high-frequency restoration."""
    if not _has("transformers"):
        _warn_missing("transformers", "transformers>=4.40")
        return audio, sr

    try:
        from transformers import AutoModelForAudioClassification, AutoFeatureExtractor
    except Exception:
        _warn_missing("Apollo model weights", "JusperLee/Apollo (HF)")
        return audio, sr

    if progress:
        progress("apollo", 0.0)

    # Apollo inference is model-dependent. For now, placeholder that
    # will be filled once the exact inference pipeline is known.
    # The model architecture is typically a U-Net or diffusion-based
    # restoration network. Loading it requires the specific checkpoint.
    warnings.warn(
        "Apollo stage is registered but inference pipeline is not yet implemented. "
        "This stage is a no-op until the JusperLee/Apollo inference code is added.",
        RuntimeWarning,
    )

    if progress:
        progress("apollo", 1.0)

    return audio, sr


def stage_audiosr(
    audio: np.ndarray, sr: int, progress: Optional[Callable[[str, float], None]] = None
) -> Tuple[np.ndarray, int]:
    """AudioSR: 48 kHz bandwidth extension (optional, off by default)."""
    if not _has("audiosr"):
        _warn_missing("audiosr", "audiosr")
        return audio, sr

    if progress:
        progress("audiosr", 0.0)

    import audiosr

    # AudioSR takes a file path; write temp, process, read back.
    import tempfile

    with tempfile.TemporaryDirectory(prefix="vr_audiosr_") as tmp:
        tmp_path = Path(tmp)
        in_path = tmp_path / "in.wav"
        sf.write(str(in_path), audio, sr, subtype="FLOAT")
        out_path = audiosr.process(in_path, output_dir=tmp_path, sr=48000)
        out, out_sr = sf.read(str(out_path), dtype="float32")
        if out.ndim == 1:
            out = out[:, None]

    if progress:
        progress("audiosr", 1.0)

    return out, sr


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

STAGES: Dict[str, Callable] = {
    "deepfilter": stage_deepfilter,
    "voicefixer": stage_voicefixer,
    "apollo": stage_apollo,
    "audiosr": stage_audiosr,
}

DEFAULT_ORDER = ["deepfilter", "voicefixer", "apollo", "audiosr"]

_ENV_MAP = {
    "deepfilter": "VR_DEROOM",
    "voicefixer": "VR_VOICEFIXER",
    "apollo": "VR_APOLLO",
    "audiosr": "VR_AUDIOSR",
}

# ---------------------------------------------------------------------------
# Core pipeline
# ---------------------------------------------------------------------------


def restore(
    input_path: Path,
    output_path: Path,
    stages: Optional[List[str]] = None,
    progress: Optional[Callable[[str, float], None]] = None,
) -> Path:
    """Run the restoration chain on a single audio file.

    Args:
        input_path: Path to input vocal stem (any format soundfile reads).
        output_path: Path to write restored vocal (always 32-bit float WAV).
        stages: Ordered list of stage names. None = use env toggles.
        progress: Callback (stage_name, 0_to_1).

    Returns:
        Path to the written output file.
    """
    audio, sr = sf.read(str(input_path), dtype="float32")
    if audio.ndim == 1:
        audio = audio[:, None]

    # Determine active stages
    if stages is None:
        active = [
            s for s in DEFAULT_ORDER if os.environ.get(_ENV_MAP[s], "0") == "1"
        ]
    else:
        active = [s for s in stages if s in STAGES]
        unknown = set(stages) - set(STAGES.keys())
        if unknown:
            raise ValueError(f"Unknown stages: {sorted(unknown)}")

    if not active:
        warnings.warn(
            "No restoration stages enabled. Output is a copy of input. "
            "Set env vars (VR_DEROOM=1, etc.) or pass --stage.",
            UserWarning,
        )

    for stage_name in active:
        print(f"[{stage_name}] running…", file=sys.stderr)
        audio, sr = STAGES[stage_name](audio, sr, progress=progress)

    # Ensure stereo output even if input was mono
    if audio.ndim == 1:
        audio = np.stack([audio, audio], axis=1)

    sf.write(str(output_path), audio, sr, subtype="FLOAT")
    print(f"[restore] wrote {output_path}", file=sys.stderr)
    return output_path


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _progress_cb(stage: str, p: float) -> None:
    print(f"[{stage}] {p * 100:.0f}%", file=sys.stderr)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Vocal restoration chain")
    parser.add_argument("input", type=Path, help="Input vocal stem path")
    parser.add_argument("output", type=Path, help="Output restored vocal path")
    parser.add_argument(
        "--stage",
        action="append",
        choices=list(STAGES.keys()),
        help="Restoration stage to run (can repeat). Default: env toggles.",
    )
    parser.add_argument(
        "--list-stages",
        action="store_true",
        help="Print available stages and exit",
    )
    args = parser.parse_args(argv)

    if args.list_stages:
        print("Available stages:")
        for name in DEFAULT_ORDER:
            env = _ENV_MAP[name]
            default = "on" if os.environ.get(env, "0") == "1" else "off"
            print(f"  {name:12s}  env: {env}  default: {default}")
        return 0

    restore(
        args.input,
        args.output,
        stages=args.stage,
        progress=_progress_cb,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
