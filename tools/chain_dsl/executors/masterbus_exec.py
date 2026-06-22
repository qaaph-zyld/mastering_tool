"""Executor that emits the flat `chain.json` consumed by `master_bus.rs`."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict

from ..schema import Chain


def to_masterbus_config(chain: Chain) -> Dict[str, Any]:
    """Return the MasterBusConfig-compatible dict (lossy for deesser)."""
    return chain.to_masterbus_dict()


def render_json(chain: Chain, path: Path | str) -> None:
    """Write the chain as a flat `chain.json` for the Rust master bus."""
    Path(path).write_text(
        json.dumps(to_masterbus_config(chain), indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
