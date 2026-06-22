"""Whisper-driven vocal QC for mastering_tool.

Transcribes vocal tracks with faster-whisper, detects artifacts
(clipped words, missing breaths, pitch drift placeholder), and
produces a markdown report.

Hardware budget: CPU-only, int8 quantization.
Default model: faster-whisper large-v3 int8 (fallback medium.en int8).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import wave
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


class ArtifactType(Enum):
    LOW_CONFIDENCE = "low_confidence"
    MISSING_BREATH = "missing_breath"
    PITCH_DRIFT = "pitch_drift"
    LONG_GAP = "long_gap"


@dataclass
class Artifact:
    type: ArtifactType
    start: float
    end: float
    text: str
    details: str = ""


@dataclass
class VocalQCResult:
    track_name: str
    transcript: str
    words: List[Dict[str, Any]] = field(default_factory=list)
    artifacts: List[Artifact] = field(default_factory=list)
    flagged: bool = False
    model_name: str = ""
    processing_time_s: float = 0.0


def load_whisper_model(
    model_size: str = "large-v3",
    compute_type: str = "int8",
    device: str = "cpu",
) -> Any:
    """Load a faster-whisper model. Falls back on OOM or import error."""
    try:
        from faster_whisper import WhisperModel
    except ImportError as exc:
        raise RuntimeError(
            "faster-whisper not installed. "
            f"Install with: pip install -r tools/vocal_qc/requirements.txt"
        ) from exc

    try:
        model = WhisperModel(model_size, device=device, compute_type=compute_type)
        return model
    except Exception as exc:
        # If large-v3 fails (OOM etc.), fall back to medium.en
        if model_size != "medium.en":
            print(f"  WARN: {model_size} failed ({exc}), falling back to medium.en")
            return WhisperModel("medium.en", device=device, compute_type=compute_type)
        raise


def get_audio_duration(path: Path) -> float:
    """Return duration in seconds using wave or ffmpeg probe."""
    try:
        with wave.open(str(path), "rb") as wf:
            frames = wf.getnframes()
            rate = wf.getframerate()
            return frames / rate
    except wave.Error:
        pass
    # Fallback: ffprobe
    import subprocess
    result = subprocess.run(
        [
            "ffprobe", "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        capture_output=True, text=True,
    )
    if result.returncode == 0 and result.stdout.strip():
        return float(result.stdout.strip())
    return 0.0


def transcribe(
    model: Any,
    audio_path: Path,
    language: Optional[str] = "en",
    word_timestamps: bool = True,
) -> Tuple[str, List[Dict[str, Any]], float]:
    """Transcribe audio and return (full_text, word_list, duration)."""
    segments, info = model.transcribe(
        str(audio_path),
        language=language,
        word_timestamps=word_timestamps,
        vad_filter=True,
    )

    words: List[Dict[str, Any]] = []
    full_text_parts: List[str] = []
    for segment in segments:
        full_text_parts.append(segment.text)
        if segment.words:
            for w in segment.words:
                words.append(
                    {
                        "word": w.word.strip(),
                        "start": w.start,
                        "end": w.end,
                        "confidence": getattr(w, "probability", 0.0),
                    }
                )

    full_text = " ".join(full_text_parts).strip()
    duration = get_audio_duration(audio_path)
    return full_text, words, duration


def detect_artifacts(
    words: List[Dict[str, Any]],
    duration: float,
    confidence_threshold: float = 0.6,
    gap_threshold: float = 2.0,
) -> List[Artifact]:
    """Detect vocal artifacts from word-level timestamps."""
    artifacts: List[Artifact] = []

    # 1. Low-confidence words
    for w in words:
        conf = w.get("confidence", 1.0)
        if conf < confidence_threshold:
            artifacts.append(
                Artifact(
                    type=ArtifactType.LOW_CONFIDENCE,
                    start=w["start"],
                    end=w["end"],
                    text=w["word"],
                    details=f"confidence={conf:.2f} (< {confidence_threshold})",
                )
            )

    # 2. Long gaps between words (possible missing breaths / dropouts)
    for i in range(1, len(words)):
        prev_end = words[i - 1]["end"]
        curr_start = words[i]["start"]
        gap = curr_start - prev_end
        if gap > gap_threshold:
            artifacts.append(
                Artifact(
                    type=ArtifactType.MISSING_BREATH,
                    start=prev_end,
                    end=curr_start,
                    text="",
                    details=f"gap={gap:.2f}s (> {gap_threshold}s)",
                )
            )

    # 3. Long gaps at start/end (truncation check)
    if words:
        if words[0]["start"] > 1.0:
            artifacts.append(
                Artifact(
                    type=ArtifactType.LONG_GAP,
                    start=0.0,
                    end=words[0]["start"],
                    text="",
                    details=f"lead-in={words[0]['start']:.2f}s",
                )
            )
        if duration - words[-1]["end"] > 1.0:
            artifacts.append(
                Artifact(
                    type=ArtifactType.LONG_GAP,
                    start=words[-1]["end"],
                    end=duration,
                    text="",
                    details=f"tail={duration - words[-1]['end']:.2f}s",
                )
            )

    # 4. Pitch drift placeholder
    # Real implementation would use crepe/pyin; skip for CPU budget.
    # artifacts.append(Artifact(...))  # reserved

    return artifacts


def run_vocal_qc(
    audio_path: Path,
    model_size: str = "large-v3",
    compute_type: str = "int8",
    confidence_threshold: float = 0.6,
    gap_threshold: float = 2.0,
    language: Optional[str] = "en",
) -> VocalQCResult:
    """Run the full vocal QC pipeline on one audio file."""
    import time

    t0 = time.time()
    track_name = audio_path.stem

    model = load_whisper_model(model_size, compute_type)
    full_text, words, duration = transcribe(model, audio_path, language=language)
    artifacts = detect_artifacts(
        words, duration, confidence_threshold, gap_threshold
    )

    # Flag if any artifacts found
    flagged = len(artifacts) > 0

    elapsed = time.time() - t0
    return VocalQCResult(
        track_name=track_name,
        transcript=full_text,
        words=words,
        artifacts=artifacts,
        flagged=flagged,
        model_name=model_size,
        processing_time_s=elapsed,
    )


def write_report(result: VocalQCResult, output_path: Path) -> None:
    """Write a VOCAL_QC_REPORT.md."""
    lines = [
        "# Vocal QC Report",
        "",
        f"**Track**: {result.track_name}",
        f"**Model**: {result.model_name}",
        f"**Processing time**: {result.processing_time_s:.1f}s",
        f"**Flagged for review**: {'YES' if result.flagged else 'NO'}",
        "",
        "## Transcript",
        "",
        result.transcript,
        "",
        "## Artifacts",
        "",
    ]

    if not result.artifacts:
        lines.append("No artifacts detected.")
    else:
        lines.append(f"Total artifacts: {len(result.artifacts)}")
        lines.append("")
        lines.append("| Type | Time (s) | Word / Detail |")
        lines.append("|------|----------|---------------|")
        for art in result.artifacts:
            time_range = f"{art.start:.2f} – {art.end:.2f}"
            lines.append(f"| {art.type.value} | {time_range} | {art.text or art.details} |")

    lines += [
        "",
        "## Word-level detail",
        "",
        "| # | Word | Start | End | Confidence |",
        "|---|------|-------|-----|------------|",
    ]
    for i, w in enumerate(result.words[:50], 1):
        conf = w.get("confidence", 0.0)
        conf_str = f"{conf:.2f}" if conf else "—"
        lines.append(
            f"| {i} | {w['word']} | {w['start']:.2f} | {w['end']:.2f} | {conf_str} |"
        )
    if len(result.words) > 50:
        lines.append(f"| ... | ({len(result.words) - 50} more words) | | | |")

    lines.append("")
    output_path.write_text("\n".join(lines), encoding="utf-8")


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Whisper-driven vocal QC for mastering_tool"
    )
    parser.add_argument("audio", type=Path, help="Input vocal audio file")
    parser.add_argument(
        "--output", "-o", type=Path, default=None,
        help="Output report path (default: <audio_dir>/VOCAL_QC_REPORT.md)",
    )
    parser.add_argument(
        "--model", default="large-v3",
        choices=["tiny", "base", "small", "medium", "medium.en", "large-v1", "large-v2", "large-v3"],
        help="Whisper model size (default: large-v3)",
    )
    parser.add_argument(
        "--compute", default="int8",
        choices=["int8", "int8_float32", "float16", "float32"],
        help="CTranslate2 compute type (default: int8)",
    )
    parser.add_argument(
        "--confidence", type=float, default=0.6,
        help="Confidence threshold for flagging low-confidence words (default: 0.6)",
    )
    parser.add_argument(
        "--gap", type=float, default=2.0,
        help="Gap threshold for missing breath detection in seconds (default: 2.0)",
    )
    parser.add_argument(
        "--language", default="en",
        help="Language code for transcription (default: en)",
    )
    args = parser.parse_args(argv)

    if not args.audio.exists():
        print(f"ERROR: audio file not found: {args.audio}", file=sys.stderr)
        return 1

    output_path = args.output or (args.audio.parent / "VOCAL_QC_REPORT.md")

    print(f">>> Vocal QC: {args.audio.name}")
    print(f"    Model: {args.model} ({args.compute})")
    result = run_vocal_qc(
        audio_path=args.audio,
        model_size=args.model,
        compute_type=args.compute,
        confidence_threshold=args.confidence,
        gap_threshold=args.gap,
        language=args.language,
    )
    write_report(result, output_path)
    print(f"    Flagged: {'YES' if result.flagged else 'NO'}")
    print(f"    Artifacts: {len(result.artifacts)}")
    print(f"    Report: {output_path}")
    return 0 if not result.flagged else 2


if __name__ == "__main__":
    sys.exit(main())
