"""Parse a mastering pipeline script and emit a MasterBusConfig-compatible chain.json.

Usage:
    python generate_chain_json.py master_pipeline.sh [--out chain.json]

Extracts parameters from FFmpeg -af filtergraphs and comments, producing a JSON
file that `open_DAW/daw-engine/src/master_bus.rs` can load via `MasterBusConfig`.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


def parse_eq_bands(af_line: str) -> List[Tuple[float, float, float]]:
    """Extract equalizer parameters from an FFmpeg -af line.

    Returns list of (freq_hz, gain_db, q).
    """
    bands = []
    # equalizer=f=3500:t=q:w=1.2:g=0.7
    for m in re.finditer(
        r'equalizer=f=(\d+(?:\.\d+)?):t=q:w=(\d+(?:\.\d+)?):g=([+-]?\d+(?:\.\d+)?)',
        af_line,
    ):
        freq = float(m.group(1))
        q = float(m.group(2))
        gain = float(m.group(3))
        bands.append((freq, gain, q))
    return bands


def parse_compressor(af_line: str) -> Optional[Dict[str, float]]:
    """Extract acompressor parameters from an FFmpeg -af line."""
    # acompressor=threshold=-14dB:ratio=1.5:attack=25:release=200:makeup=1.0:knee=4
    m = re.search(
        r'acompressor=threshold=([+-]?\d+(?:\.\d+)?)dB:ratio=(\d+(?:\.\d+)?):attack=(\d+(?:\.\d+)?):release=(\d+(?:\.\d+)?)',
        af_line,
    )
    if m:
        return {
            "threshold_db": float(m.group(1)),
            "ratio": float(m.group(2)),
            "attack_ms": float(m.group(3)),
            "release_ms": float(m.group(4)),
        }
    return None


def parse_limiter(af_line: str) -> Optional[Dict[str, float]]:
    """Extract alimiter ceiling from an FFmpeg -af line."""
    # alimiter=limit=0.85:attack=2:release=80:level=disabled
    m = re.search(r'alimiter=limit=(\d+(?:\.\d+)?)', af_line)
    if m:
        limit_linear = float(m.group(1))
        # Convert linear amplitude to dBFS
        ceiling_db = 20.0 * math.log10(limit_linear) if limit_linear > 0 else -99.0
        return {"limit_ceiling_db": ceiling_db}
    return None


def parse_highpass(af_line: str) -> Optional[float]:
    """Extract highpass frequency from an FFmpeg -af line."""
    # highpass=f=25:poles=2
    m = re.search(r'highpass=f=(\d+(?:\.\d+)?)', af_line)
    if m:
        return float(m.group(1))
    return None


def parse_volume(af_line: str) -> Optional[float]:
    """Extract volume gain from an FFmpeg -af line."""
    # volume=-3dB or volume=+11.0dB
    m = re.search(r'volume=([+-]?\d+(?:\.\d+)?)dB', af_line)
    if m:
        return float(m.group(1))
    return None


def extract_from_comments(text: str) -> Dict[str, Any]:
    """Extract parameters from script comments as fallback / enrichment.

    The scripts are heavily commented with lines like:
        # th -14dB, ratio 1.5, attack 25ms, release 200ms, knee 4, makeup 1.0
    """
    params: Dict[str, Any] = {}

    # Compressor from comments
    comp_re = re.search(
        r'#\s*(?:th|threshold)\s*=?\s*([+-]?\d+(?:\.\d+)?)\s*dB.*?ratio\s*=?\s*(\d+(?:\.\d+)?).*?attack\s*=?\s*(\d+(?:\.\d+)?)\s*ms.*?release\s*=?\s*(\d+(?:\.\d+)?)\s*ms',
        text,
        re.IGNORECASE | re.DOTALL,
    )
    if comp_re:
        params["comp_threshold_db"] = float(comp_re.group(1))
        params["comp_ratio"] = float(comp_re.group(2))
        params["comp_attack_ms"] = float(comp_re.group(3))
        params["comp_release_ms"] = float(comp_re.group(4))

    # Limiter ceiling from comments
    limit_re = re.search(
        r'#.*?limit(?:er)?.*?([+-]?\d+(?:\.\d+)?)\s*dB(?:TP|FS)?',
        text,
        re.IGNORECASE | re.DOTALL,
    )
    if limit_re:
        params["limit_ceiling_db"] = float(limit_re.group(1))

    # HPF from comments
    hpf_re = re.search(r'HPF\s+(\d+(?:\.\d+)?)\s*Hz', text, re.IGNORECASE)
    if hpf_re:
        params["hpf_freq"] = float(hpf_re.group(1))

    return params


def extract_af_text(text: str) -> str:
    """Extract all -af filtergraph text from a bash script.

    Handles multi-line quoted strings and line continuations.
    """
    # Find all quoted strings that follow -af
    # This regex finds -af followed by a quoted string (possibly multi-line)
    pattern = re.compile(
        r'-af\s+"([^"]*)"',
        re.DOTALL,
    )
    matches = pattern.findall(text)
    # Also handle single-quoted variants
    pattern2 = re.compile(r"-af\s+'([^']*)'", re.DOTALL)
    matches.extend(pattern2.findall(text))
    return " ".join(matches)


def parse_script(path: Path) -> Dict[str, Any]:
    """Parse a master_pipeline*.sh script into a MasterBusConfig-like dict."""
    text = path.read_text(encoding="utf-8")

    config: Dict[str, Any] = {
        "sample_rate": 48000.0,
        "hpf_freq": 30.0,
        "hpf_bypass": True,
        "eq_bands": [],
        "eq_bypass": True,
        "comp_threshold_db": -18.0,
        "comp_ratio": 1.5,
        "comp_attack_ms": 10.0,
        "comp_release_ms": 100.0,
        "comp_bypass": True,
        "clip_drive_db": 2.0,
        "clip_bypass": True,
        "limit_ceiling_db": -1.0,
        "limit_lookahead_ms": 20.0,
        "limit_bypass": True,
    }

    # Extract from comments first (often more reliable / explicit)
    comment_params = extract_from_comments(text)
    config.update(comment_params)

    # Track which stages we've found
    has_hpf = False
    has_eq = False
    has_comp = False
    has_limit = False

    # Extract all -af filtergraph text
    af_text = extract_af_text(text)

    if af_text:
        # EQ
        eq_bands = parse_eq_bands(af_text)
        if eq_bands:
            config["eq_bands"].extend(eq_bands)
            has_eq = True

        # Compressor
        comp = parse_compressor(af_text)
        if comp:
            config.update({f"comp_{k}": v for k, v in comp.items()})
            has_comp = True

        # Limiter
        limit = parse_limiter(af_text)
        if limit:
            config.update(limit)
            has_limit = True

        # HPF
        hpf = parse_highpass(af_text)
        if hpf is not None:
            config["hpf_freq"] = hpf
            has_hpf = True

    # Set bypass flags based on whether we found the stage
    config["hpf_bypass"] = not has_hpf
    config["eq_bypass"] = not has_eq
    config["comp_bypass"] = not has_comp
    config["limit_bypass"] = not has_limit

    # Soft-clipper is not present in FFmpeg scripts; keep bypassed
    config["clip_bypass"] = True

    return config


def main() -> None:
    parser = argparse.ArgumentParser(description="Parse mastering pipeline script to chain.json")
    parser.add_argument("script", help="Path to master_pipeline*.sh")
    parser.add_argument("--out", "-o", default="chain.json", help="Output JSON path")
    args = parser.parse_args()

    script_path = Path(args.script)
    if not script_path.exists():
        print(f"ERROR: script not found: {script_path}", file=sys.stderr)
        sys.exit(1)

    config = parse_script(script_path)
    out_path = Path(args.out)
    out_path.write_text(json.dumps(config, indent=2), encoding="utf-8")
    print(f"Wrote {out_path} ({len(config)} fields)")


if __name__ == "__main__":
    main()
