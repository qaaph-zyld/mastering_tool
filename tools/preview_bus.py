"""Preview bus — audition a mastering chain without bouncing the full track.

Usage:
    python preview_bus.py <pipeline_script.sh> <source.wav> [--out preview.wav] [--duration 30]

1. Parses the pipeline script into chain.json via generate_chain_json.py.
2. Runs FFmpeg with the same filtergraph on a short segment of the source.
3. Writes a preview WAV that can be A/B'd against the unprocessed source.

This lets you audition the mastering chain in real time (well, fast-rendered)
without waiting for the full pipeline to finish.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

# Add tools directory to path for generate_chain_json import
sys.path.insert(0, str(Path(__file__).parent))
from generate_chain_json import parse_script


def build_ffmpeg_af(config: dict) -> str:
    """Build an FFmpeg -af filtergraph from a chain.json config dict.

    This is a best-effort reconstruction; some Rust-native features (soft-clipper,
    lookahead limiter) have no exact FFmpeg equivalent and are approximated.
    """
    filters = []

    # HPF
    if not config.get("hpf_bypass", True):
        freq = config.get("hpf_freq", 30.0)
        filters.append(f"highpass=f={freq}:poles=2")

    # EQ bands
    if not config.get("eq_bypass", True):
        for freq, gain, q in config.get("eq_bands", []):
            filters.append(f"equalizer=f={freq}:t=q:w={q}:g={gain}")

    # Compressor
    if not config.get("comp_bypass", True):
        th = config.get("comp_threshold_db", -18.0)
        ratio = config.get("comp_ratio", 1.5)
        attack = config.get("comp_attack_ms", 10.0)
        release = config.get("comp_release_ms", 100.0)
        filters.append(
            f"acompressor=threshold={th}dB:ratio={ratio}:attack={attack}:release={release}:makeup=1.0:knee=4"
        )

    # Soft-clipper (approximated with aclip)
    if not config.get("clip_bypass", True):
        # FFmpeg doesn't have a direct soft-clipper; use alimiter as approximation
        filters.append("alimiter=limit=0.95:attack=1:release=1:level=disabled")

    # Limiter
    if not config.get("limit_bypass", True):
        ceiling = config.get("limit_ceiling_db", -1.0)
        linear = 10.0 ** (ceiling / 20.0)
        filters.append(f"alimiter=limit={linear:.4f}:attack=2:release=80:level=disabled")

    return ",".join(filters) if filters else "anull"


def run_preview(
    pipeline_script: Path,
    source_wav: Path,
    output_wav: Path,
    duration: float | None = None,
    start: float = 0.0,
) -> None:
    """Generate a preview WAV by applying the parsed chain to a segment of source."""
    config = parse_script(pipeline_script)
    af = build_ffmpeg_af(config)

    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-y",
        "-ss", str(start),
        "-i", str(source_wav),
    ]
    if duration is not None:
        cmd += ["-t", str(duration)]
    cmd += [
        "-af", af,
        "-c:a", "pcm_f32le",
        str(output_wav),
    ]

    print(f"Preview filtergraph: {af}")
    print(f"Running: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)
    print(f"Preview written to: {output_wav}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Audition a mastering chain preview")
    parser.add_argument("pipeline", help="Path to master_pipeline*.sh")
    parser.add_argument("source", help="Source WAV to preview")
    parser.add_argument("--out", "-o", default="preview.wav", help="Output preview WAV")
    parser.add_argument("--duration", "-t", type=float, default=30.0, help="Preview duration in seconds")
    parser.add_argument("--start", "-ss", type=float, default=0.0, help="Start offset in seconds")
    args = parser.parse_args()

    pipeline_path = Path(args.pipeline)
    source_path = Path(args.source)
    out_path = Path(args.out)

    if not pipeline_path.exists():
        print(f"ERROR: pipeline script not found: {pipeline_path}", file=sys.stderr)
        sys.exit(1)
    if not source_path.exists():
        print(f"ERROR: source file not found: {source_path}", file=sys.stderr)
        sys.exit(1)

    run_preview(pipeline_path, source_path, out_path, duration=args.duration, start=args.start)


if __name__ == "__main__":
    main()
