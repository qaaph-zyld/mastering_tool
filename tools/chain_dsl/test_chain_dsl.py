"""Tests for the Plugin Chain DSL and its executors."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest

from .schema import Chain, Compressor, Deesser, EQ, EQBand, HPF, Limiter
from .executors import masterbus_exec, pedalboard_exec


def test_yaml_roundtrip(tmp_path: Path) -> None:
    chain = Chain(
        sample_rate=48000.0,
        hpf=HPF(freq=80.0, slope=12, bypass=False),
        eq=EQ(
            bands=[
                EQBand(freq=250.0, gain=-2.5, q=1.2),
                EQBand(freq=6300.0, gain=1.5, q=2.0),
            ],
            bypass=False,
        ),
        deesser=Deesser(freq=6800.0, threshold_db=-28.0, ratio=4.0, bypass=False),
        comp=Compressor(threshold_db=-18.0, ratio=3.0, attack_ms=5.0, release_ms=80.0),
    )
    path = tmp_path / "chain.yaml"
    chain.to_yaml(path)
    restored = Chain.from_yaml(path)
    assert restored.to_dict() == chain.to_dict()


def test_masterbus_roundtrip(tmp_path: Path) -> None:
    chain = Chain(
        sample_rate=48000.0,
        hpf=HPF(freq=25.0, bypass=False),
        eq=EQ(
            bands=[
                EQBand(freq=3500.0, gain=0.7, q=1.2),
                EQBand(freq=7000.0, gain=0.5, q=1.0),
                EQBand(freq=12000.0, gain=1.6, q=0.7),
            ],
            bypass=False,
        ),
        comp=Compressor(
            threshold_db=-14.0, ratio=1.5, attack_ms=25.0, release_ms=200.0
        ),
        limit=Limiter(ceiling_db=-1.41),
    )
    mb_path = tmp_path / "chain.json"
    masterbus_exec.render_json(chain, mb_path)

    flat = json.loads(mb_path.read_text(encoding="utf-8"))
    restored = Chain.from_masterbus_dict(flat)
    restored_json = restored.to_masterbus_dict()

    # Round-trip must be lossless for the stages the master bus supports.
    assert restored_json == flat

    # The deesser is preserved in the YAML but not in the master bus JSON.
    assert flat["eq_bands"] == [
        [3500.0, 0.7, 1.2],
        [7000.0, 0.5, 1.0],
        [12000.0, 1.6, 0.7],
    ]
    assert flat["comp_threshold_db"] == -14.0
    assert flat["limit_ceiling_db"] == pytest.approx(-1.41, abs=0.01)


def test_pedalboard_render_preserves_shape() -> None:
    sr = 48000
    chain = Chain(
        sample_rate=float(sr),
        hpf=HPF(freq=100.0, bypass=False),
        eq=EQ(bands=[EQBand(freq=3000.0, gain=2.0, q=1.5)], bypass=False),
        comp=Compressor(threshold_db=-20.0, ratio=2.0, bypass=False),
        limit=Limiter(ceiling_db=-2.0, bypass=False),
    )
    x = np.random.randn(sr, 2).astype(np.float32)
    y = pedalboard_exec.render(chain, x)
    assert y.shape == x.shape
    assert y.dtype == x.dtype


def test_pedalboard_bypass_is_passthrough() -> None:
    sr = 48000
    chain = Chain(sample_rate=float(sr))
    x = np.random.randn(sr, 2).astype(np.float32)
    y = pedalboard_exec.render(chain, x)
    np.testing.assert_allclose(y, x, atol=1e-6)


def test_pedalboard_mono_render() -> None:
    sr = 48000
    chain = Chain(
        sample_rate=float(sr),
        hpf=HPF(freq=120.0, bypass=False),
    )
    x = np.random.randn(sr).astype(np.float32)
    y = pedalboard_exec.render(chain, x)
    assert y.shape == x.shape
