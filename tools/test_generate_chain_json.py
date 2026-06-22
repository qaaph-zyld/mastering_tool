"""Tests for generate_chain_json.py."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

import pytest

from generate_chain_json import parse_script


SAMPLE_SCRIPT = """#!/bin/bash
# Test pipeline
# HPF 50Hz
# th -12dB, ratio 2.0, attack 10ms, release 150ms

ffmpeg -i input.wav \
    -af "volume=-3dB,highpass=f=50:poles=2" \
    -c:a pcm_f32le step1.wav

ffmpeg -i step1.wav \
    -af "equalizer=f=200:t=q:w=0.7:g=-2.0,equalizer=f=3000:t=q:w=1.0:g=3.0" \
    -c:a pcm_f32le step2.wav

ffmpeg -i step2.wav \
    -af "acompressor=threshold=-12dB:ratio=2.0:attack=10:release=150:makeup=1.0:knee=4" \
    -c:a pcm_f32le step3.wav

ffmpeg -i step3.wav \
    -af "volume=+8.0dB,aresample=192000:resampler=soxr:precision=28,alimiter=limit=0.90:attack=2:release=80:level=disabled,aresample=48000:resampler=soxr:precision=28" \
    -c:a pcm_f32le output.wav
"""


def test_parse_sample_script():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".sh", delete=False) as f:
        f.write(SAMPLE_SCRIPT)
        f.flush()
        path = Path(f.name)

    config = parse_script(path)
    path.unlink()

    assert config["sample_rate"] == 48000.0
    assert config["hpf_freq"] == 50.0
    assert config["hpf_bypass"] is False

    assert len(config["eq_bands"]) == 2
    assert config["eq_bands"][0] == (200.0, -2.0, 0.7)
    assert config["eq_bands"][1] == (3000.0, 3.0, 1.0)
    assert config["eq_bypass"] is False

    assert config["comp_threshold_db"] == -12.0
    assert config["comp_ratio"] == 2.0
    assert config["comp_attack_ms"] == 10.0
    assert config["comp_release_ms"] == 150.0
    assert config["comp_bypass"] is False

    # limit=0.90 → 20*log10(0.90) ≈ -0.915 dBFS
    assert config["limit_ceiling_db"] == pytest.approx(-0.915, abs=0.01)
    assert config["limit_bypass"] is False

    assert config["clip_bypass"] is True


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
