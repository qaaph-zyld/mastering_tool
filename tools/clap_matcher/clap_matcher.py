"""CLAP reference matching for mastering_tool.

Compare a mastered track against the reference library using
Contrastive Language-Audio Pretraining (CLAP) embeddings.

Model: laion/clap-htsat-fused (HuggingFace), CPU inference.
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import warnings
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

# Suppress benign transformers warnings
warnings.filterwarnings("ignore", message=".*torch.*cuda.*")


@dataclass
class ReferenceEntry:
    name: str
    path: Path
    metadata: Dict[str, Any] = field(default_factory=dict)
    embedding: Optional[np.ndarray] = None


@dataclass
class MatchResult:
    rank: int
    name: str
    similarity: float
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class CLAPMatchResult:
    track_name: str
    top_matches: List[MatchResult] = field(default_factory=list)
    report_path: Optional[Path] = None


def load_clap_model(model_name: str = "laion/clap-htsat-fused", device: str = "cpu") -> Any:
    """Load a CLAP model from HuggingFace transformers.

    Falls back to feature-extraction mode if the full model errors.
    """
    try:
        from transformers import ClapModel, ClapProcessor
    except ImportError as exc:
        raise RuntimeError(
            "transformers not installed. "
            "Install with: pip install -r tools/clap_matcher/requirements.txt"
        ) from exc

    try:
        processor = ClapProcessor.from_pretrained(model_name)
        model = ClapModel.from_pretrained(model_name)
        model = model.to(device)
        model.eval()
        return model, processor
    except Exception as exc:
        raise RuntimeError(f"Failed to load CLAP model '{model_name}': {exc}") from exc


def load_audio(path: Path, target_sr: int = 48000, max_duration_s: float = 30.0) -> np.ndarray:
    """Load audio with librosa, resample, and truncate to max_duration."""
    try:
        import librosa
    except ImportError as exc:
        raise RuntimeError(
            "librosa not installed. "
            "Install with: pip install -r tools/clap_matcher/requirements.txt"
        ) from exc

    audio, sr = librosa.load(str(path), sr=target_sr, mono=True)
    max_samples = int(target_sr * max_duration_s)
    if len(audio) > max_samples:
        audio = audio[:max_samples]
    return audio


def compute_embedding(model: Any, processor: Any, audio: np.ndarray, device: str = "cpu") -> np.ndarray:
    """Compute CLAP audio embedding."""
    import torch

    inputs = processor(audios=audio, return_tensors="pt", sampling_rate=48000)
    inputs = {k: v.to(device) for k, v in inputs.items()}
    with torch.no_grad():
        outputs = model.get_audio_features(**inputs)
    emb = outputs.cpu().numpy()
    # Normalize to unit vector for cosine similarity
    norm = np.linalg.norm(emb, axis=1, keepdims=True)
    return emb / (norm + 1e-8)


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Cosine similarity between two normalized vectors."""
    return float(np.dot(a, b.T).item())


def load_reference_library(csv_path: Path) -> List[ReferenceEntry]:
    """Load reference entries from REFERENCE_LIBRARY.csv.

    Derives audio paths from names by matching against *_MASTER_32f.wav
    in the Distro Kidea directory.
    """
    entries: List[ReferenceEntry] = []
    distro = Path("D:/Projects/Music-AI-Toolshop/Distro Kidea")

    if not csv_path.exists():
        raise FileNotFoundError(f"Reference library not found: {csv_path}")

    with open(csv_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row.get("name", "").strip()
            if not name:
                continue
            # Try to find the audio file
            audio_path = distro / f"{name}.wav"
            if not audio_path.exists():
                # Try with spaces replaced by underscores if needed
                alt = distro / f"{name.replace(' ', '_')}.wav"
                if alt.exists():
                    audio_path = alt
            entries.append(
                ReferenceEntry(
                    name=name,
                    path=audio_path,
                    metadata=dict(row),
                )
            )
    return entries


def cache_dir() -> Path:
    """Return the CLAP embedding cache directory."""
    cd = Path("D:/Projects/Music-AI-Toolshop/mastering_tool/.clap_cache")
    cd.mkdir(parents=True, exist_ok=True)
    return cd


def cached_embedding_path(name: str) -> Path:
    """Return the cache file path for a given reference name."""
    safe = name.replace(" ", "_").replace("/", "_")
    return cache_dir() / f"{safe}.npy"


def compute_reference_embeddings(
    entries: List[ReferenceEntry],
    model: Any,
    processor: Any,
    device: str = "cpu",
    force_recompute: bool = False,
) -> List[ReferenceEntry]:
    """Compute or load cached embeddings for all reference entries."""
    for entry in entries:
        cache_path = cached_embedding_path(entry.name)
        if not force_recompute and cache_path.exists():
            entry.embedding = np.load(cache_path)
            continue
        if not entry.path.exists():
            print(f"  SKIP (no audio): {entry.name}")
            continue
        try:
            audio = load_audio(entry.path)
            emb = compute_embedding(model, processor, audio, device=device)
            entry.embedding = emb
            np.save(cache_path, emb)
            print(f"  EMBEDDED: {entry.name}")
        except Exception as exc:
            print(f"  ERROR embedding {entry.name}: {exc}")
    return entries


def match_track(
    track_path: Path,
    entries: List[ReferenceEntry],
    model: Any,
    processor: Any,
    device: str = "cpu",
    top_k: int = 5,
) -> List[MatchResult]:
    """Compute embedding for input track and rank against references."""
    audio = load_audio(track_path)
    track_emb = compute_embedding(model, processor, audio, device=device)

    scored: List[Tuple[float, ReferenceEntry]] = []
    for entry in entries:
        if entry.embedding is None:
            continue
        sim = cosine_similarity(track_emb, entry.embedding)
        scored.append((sim, entry))

    scored.sort(key=lambda x: x[0], reverse=True)

    matches: List[MatchResult] = []
    for rank, (sim, entry) in enumerate(scored[:top_k], start=1):
        matches.append(
            MatchResult(
                rank=rank,
                name=entry.name,
                similarity=sim,
                metadata=entry.metadata,
            )
        )
    return matches


def write_report(result: CLAPMatchResult, output_path: Path) -> None:
    """Write a CLAP_MATCH_REPORT.md."""
    lines = [
        "# CLAP Reference Match Report",
        "",
        f"**Track**: {result.track_name}",
        f"**Model**: laion/clap-htsat-fused",
        f"**Top-K**: {len(result.top_matches)}",
        "",
        "## Top Matches",
        "",
        "| Rank | Name | Similarity | Integrated LUFS | LRA | True Peak |",
        "|------|------|------------|-------------------|-----|-----------|",
    ]
    for m in result.top_matches:
        meta = m.metadata
        lines.append(
            f"| {m.rank} | {m.name} | {m.similarity:.4f} | "
            f"{meta.get('integrated_lufs', 'N/A')} | "
            f"{meta.get('lra_lu', 'N/A')} | "
            f"{meta.get('true_peak_dbtp', 'N/A')} |"
        )

    lines += [
        "",
        "## Interpretation",
        "",
        "- **Similarity** is cosine similarity in CLAP embedding space (0–1).",
        "- Values > 0.85 indicate strong style/sonic similarity.",
        "- Values 0.70–0.85 indicate moderate similarity.",
        "- Values < 0.70 indicate weak or no similarity.",
        "",
        "## Spectral Delta (Placeholder)",
        "",
        "Per-octave RMS delta vs each reference is reserved for future integration.",
        "",
    ]
    output_path.write_text("\n".join(lines), encoding="utf-8")


def run_clap_match(
    track_path: Path,
    library_csv: Path,
    top_k: int = 5,
    device: str = "cpu",
    model_name: str = "laion/clap-htsat-fused",
    force_recompute: bool = False,
) -> CLAPMatchResult:
    """Run the full CLAP matching pipeline."""
    print(f">>> CLAP Match: {track_path.name}")
    print(f"    Library: {library_csv}")

    model, processor = load_clap_model(model_name, device=device)
    entries = load_reference_library(library_csv)
    print(f"    Loaded {len(entries)} reference entries")

    entries = compute_reference_embeddings(
        entries, model, processor, device=device, force_recompute=force_recompute
    )

    matches = match_track(track_path, entries, model, processor, device=device, top_k=top_k)
    result = CLAPMatchResult(
        track_name=track_path.stem,
        top_matches=matches,
    )
    return result


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="CLAP reference matching for mastering_tool"
    )
    parser.add_argument("track", type=Path, help="Input mastered track")
    parser.add_argument(
        "--library", "-l", type=Path,
        default=Path("D:/Projects/Music-AI-Toolshop/mastering_tool/REFERENCE_LIBRARY.csv"),
        help="Path to REFERENCE_LIBRARY.csv",
    )
    parser.add_argument(
        "--output", "-o", type=Path, default=None,
        help="Output report path (default: <track_dir>/CLAP_MATCH_REPORT.md)",
    )
    parser.add_argument(
        "--top-k", type=int, default=5,
        help="Number of top matches to return (default: 5)",
    )
    parser.add_argument(
        "--device", default="cpu",
        choices=["cpu", "cuda"],
        help="Device for CLAP inference (default: cpu)",
    )
    parser.add_argument(
        "--model", default="laion/clap-htsat-fused",
        help="HuggingFace CLAP model name (default: laion/clap-htsat-fused)",
    )
    parser.add_argument(
        "--force-recompute", action="store_true",
        help="Recompute all reference embeddings (ignore cache)",
    )
    args = parser.parse_args(argv)

    if not args.track.exists():
        print(f"ERROR: track not found: {args.track}", file=sys.stderr)
        return 1

    output_path = args.output or (args.track.parent / "CLAP_MATCH_REPORT.md")

    result = run_clap_match(
        track_path=args.track,
        library_csv=args.library,
        top_k=args.top_k,
        device=args.device,
        model_name=args.model,
        force_recompute=args.force_recompute,
    )
    write_report(result, output_path)
    print(f"    Top match: {result.top_matches[0].name if result.top_matches else 'N/A'}")
    print(f"    Report: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
