"""Vocal QC module for mastering_tool.

Provides transcription and artifact detection using faster-whisper.
"""

from .vocal_qc import run_vocal_qc, VocalQCResult, ArtifactType, Artifact, detect_artifacts, write_report

__all__ = ["run_vocal_qc", "VocalQCResult", "ArtifactType", "Artifact", "detect_artifacts", "write_report"]
