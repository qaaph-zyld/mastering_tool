"""Dataclass schema for the Plugin Chain DSL.

The DSL is designed to be human-writable as YAML and losslessly convertible to
the flat `chain.json` consumed by `open_DAW/daw-engine/src/master_bus.rs`.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field, is_dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

try:
    import yaml

    _HAS_YAML = True
except ImportError:  # pragma: no cover
    yaml = None  # type: ignore
    _HAS_YAML = False


@dataclass
class HPF:
    freq: float = 80.0
    slope: int = 12
    bypass: bool = True


@dataclass
class EQBand:
    freq: float = 1000.0
    gain: float = 0.0
    q: float = 1.0


@dataclass
class EQ:
    bands: List[EQBand] = field(default_factory=list)
    bypass: bool = True


@dataclass
class Deesser:
    freq: float = 6800.0
    threshold_db: float = -28.0
    ratio: float = 4.0
    width_octaves: float = 0.5
    bypass: bool = True


@dataclass
class Compressor:
    threshold_db: float = -18.0
    ratio: float = 3.0
    attack_ms: float = 5.0
    release_ms: float = 80.0
    knee_db: float = 4.0
    makeup_db: float = 0.0
    bypass: bool = True


@dataclass
class Clipper:
    drive_db: float = 2.0
    bypass: bool = True


@dataclass
class Limiter:
    ceiling_db: float = -1.0
    lookahead_ms: float = 20.0
    release_ms: float = 100.0
    bypass: bool = True


@dataclass
class Chain:
    sample_rate: float = 48000.0
    hpf: HPF = field(default_factory=HPF)
    eq: EQ = field(default_factory=EQ)
    deesser: Deesser = field(default_factory=Deesser)
    comp: Compressor = field(default_factory=Compressor)
    clip: Clipper = field(default_factory=Clipper)
    limit: Limiter = field(default_factory=Limiter)

    # ------------------------------------------------------------------
    # Serialization helpers
    # ------------------------------------------------------------------

    def to_dict(self) -> Dict[str, Any]:
        return _as_shallow_dict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Chain":
        return Chain(
            sample_rate=float(data.get("sample_rate", 48000.0)),
            hpf=_load_stage(HPF, data.get("hpf", {})),
            eq=_load_eq(data.get("eq", {})),
            deesser=_load_stage(Deesser, data.get("deesser", {})),
            comp=_load_stage(Compressor, data.get("comp", {})),
            clip=_load_stage(Clipper, data.get("clip", {})),
            limit=_load_stage(Limiter, data.get("limit", {})),
        )

    def to_yaml(self, path: Path | str) -> None:
        if not _HAS_YAML:
            raise RuntimeError("pyyaml is required for YAML output")
        Path(path).write_text(
            yaml.safe_dump(self.to_dict(), sort_keys=False, default_flow_style=False),
            encoding="utf-8",
        )

    @classmethod
    def from_yaml(cls, path: Path | str) -> "Chain":
        if not _HAS_YAML:
            raise RuntimeError("pyyaml is required for YAML input")
        text = Path(path).read_text(encoding="utf-8")
        return cls.from_dict(yaml.safe_load(text))

    def to_json(self, path: Path | str) -> None:
        Path(path).write_text(
            json.dumps(self.to_dict(), indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

    @classmethod
    def from_json(cls, path: Path | str) -> "Chain":
        text = Path(path).read_text(encoding="utf-8")
        return cls.from_dict(json.loads(text))

    def to_masterbus_dict(self) -> Dict[str, Any]:
        """Emit the flat MasterBusConfig dict used by generate_chain_json.py.

        This is the lossy direction for stages the Rust master bus does not yet
        support (e.g., deesser). The deesser is preserved in the YAML but not
        in this JSON.
        """
        config: Dict[str, Any] = {
            "sample_rate": self.sample_rate,
            "hpf_freq": self.hpf.freq,
            "hpf_bypass": self.hpf.bypass,
            "eq_bands": [[b.freq, b.gain, b.q] for b in self.eq.bands],
            "eq_bypass": self.eq.bypass,
            "comp_threshold_db": self.comp.threshold_db,
            "comp_ratio": self.comp.ratio,
            "comp_attack_ms": self.comp.attack_ms,
            "comp_release_ms": self.comp.release_ms,
            "comp_bypass": self.comp.bypass,
            "clip_drive_db": self.clip.drive_db,
            "clip_bypass": self.clip.bypass,
            "limit_ceiling_db": self.limit.ceiling_db,
            "limit_lookahead_ms": self.limit.lookahead_ms,
            "limit_bypass": self.limit.bypass,
        }
        return config

    @classmethod
    def from_masterbus_dict(cls, data: Dict[str, Any]) -> "Chain":
        """Reconstruct a Chain from the flat MasterBusConfig dict."""
        return Chain(
            sample_rate=float(data.get("sample_rate", 48000.0)),
            hpf=HPF(
                freq=float(data.get("hpf_freq", 80.0)),
                bypass=bool(data.get("hpf_bypass", True)),
            ),
            eq=EQ(
                bands=[
                    EQBand(freq=float(b[0]), gain=float(b[1]), q=float(b[2]))
                    for b in data.get("eq_bands", [])
                ],
                bypass=bool(data.get("eq_bypass", True)),
            ),
            comp=Compressor(
                threshold_db=float(data.get("comp_threshold_db", -18.0)),
                ratio=float(data.get("comp_ratio", 3.0)),
                attack_ms=float(data.get("comp_attack_ms", 5.0)),
                release_ms=float(data.get("comp_release_ms", 80.0)),
                bypass=bool(data.get("comp_bypass", True)),
            ),
            clip=Clipper(
                drive_db=float(data.get("clip_drive_db", 2.0)),
                bypass=bool(data.get("clip_bypass", True)),
            ),
            limit=Limiter(
                ceiling_db=float(data.get("limit_ceiling_db", -1.0)),
                lookahead_ms=float(data.get("limit_lookahead_ms", 20.0)),
                bypass=bool(data.get("limit_bypass", True)),
            ),
        )


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _as_shallow_dict(obj: Any) -> Any:
    """Recursively convert dataclasses to plain dicts, leaving primitives alone."""
    if is_dataclass(obj):
        return {k: _as_shallow_dict(v) for k, v in asdict(obj).items()}
    if isinstance(obj, list):
        return [_as_shallow_dict(v) for v in obj]
    if isinstance(obj, tuple):
        return tuple(_as_shallow_dict(v) for v in obj)
    return obj


def _load_stage(cls: Any, data: Any) -> Any:
    """Load a single stage dataclass from a dict or an already-constructed instance."""
    if isinstance(data, cls):
        return data
    if data is None:
        return cls()
    return cls(**data)


def _load_eq(data: Any) -> EQ:
    if isinstance(data, EQ):
        return data
    if data is None:
        return EQ()
    bands = data.get("bands", [])
    return EQ(
        bands=[b if isinstance(b, EQBand) else EQBand(**b) for b in bands],
        bypass=bool(data.get("bypass", False)),
    )
