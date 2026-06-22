"""Tests for vocal_qc — mocked Whisper, no model download."""
from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from vocal_qc import (
    ArtifactType,
    detect_artifacts,
    run_vocal_qc,
    write_report,
)


class FakeSegment:
    def __init__(self, text: str, words: list):
        self.text = text
        self.words = words


class FakeWord:
    def __init__(self, word: str, start: float, end: float, prob: float = 0.9):
        self.word = word
        self.start = start
        self.end = end
        self.probability = prob


def _mock_model(words_data: list, lang: str = "en") -> MagicMock:
    """Build a mocked WhisperModel that returns given word data."""
    fake_words = [FakeWord(**w) for w in words_data]
    segment = FakeSegment(text=" ".join(w["word"] for w in words_data), words=fake_words)
    info = SimpleNamespace(language=lang, language_probability=1.0)
    model = MagicMock()
    model.transcribe.return_value = ([segment], info)
    return model


class TestDetectArtifacts:
    def test_no_artifacts_clean_track(self):
        words = [
            {"word": "hello", "start": 0.0, "end": 0.5, "confidence": 0.95},
            {"word": "world", "start": 0.6, "end": 1.1, "confidence": 0.92},
        ]
        artifacts = detect_artifacts(words, duration=2.0)
        assert not artifacts

    def test_low_confidence_flagged(self):
        words = [
            {"word": "hello", "start": 0.0, "end": 0.5, "confidence": 0.95},
            {"word": "mumbled", "start": 0.6, "end": 1.1, "confidence": 0.45},
        ]
        artifacts = detect_artifacts(words, duration=2.0, confidence_threshold=0.6)
        assert len(artifacts) == 1
        assert artifacts[0].type == ArtifactType.LOW_CONFIDENCE
        assert artifacts[0].text == "mumbled"

    def test_missing_breath_gap(self):
        words = [
            {"word": "hello", "start": 0.0, "end": 0.5, "confidence": 0.95},
            {"word": "world", "start": 3.0, "end": 3.5, "confidence": 0.92},
        ]
        artifacts = detect_artifacts(words, duration=5.0, gap_threshold=2.0)
        # missing_breath (2.5s gap) + long_gap tail (1.5s)
        assert len(artifacts) == 2
        breath = [a for a in artifacts if a.type == ArtifactType.MISSING_BREATH][0]
        assert "2.50s" in breath.details

    def test_lead_in_gap(self):
        words = [
            {"word": "late", "start": 2.5, "end": 3.0, "confidence": 0.95},
        ]
        artifacts = detect_artifacts(words, duration=5.0)
        assert any(a.type == ArtifactType.LONG_GAP for a in artifacts)

    def test_tail_gap(self):
        words = [
            {"word": "short", "start": 0.0, "end": 0.5, "confidence": 0.95},
        ]
        artifacts = detect_artifacts(words, duration=10.0)
        assert any(a.type == ArtifactType.LONG_GAP for a in artifacts)


class TestRunVocalQC:
    @patch("vocal_qc.vocal_qc.load_whisper_model")
    @patch("vocal_qc.vocal_qc.get_audio_duration")
    def test_clean_track_no_flags(self, mock_dur, mock_load):
        mock_load.return_value = _mock_model([
            {"word": "hello", "start": 0.0, "end": 0.5, "prob": 0.95},
            {"word": "world", "start": 0.6, "end": 1.1, "prob": 0.92},
        ])
        mock_dur.return_value = 2.0

        result = run_vocal_qc(Path("fake.wav"))
        assert result.track_name == "fake"
        assert result.transcript == "hello world"
        assert not result.flagged
        assert len(result.artifacts) == 0

    @patch("vocal_qc.vocal_qc.load_whisper_model")
    @patch("vocal_qc.vocal_qc.get_audio_duration")
    def test_flagged_low_confidence(self, mock_dur, mock_load):
        mock_load.return_value = _mock_model([
            {"word": "hello", "start": 0.0, "end": 0.5, "prob": 0.95},
            {"word": "uhh", "start": 0.6, "end": 1.1, "prob": 0.45},
        ])
        mock_dur.return_value = 2.0

        result = run_vocal_qc(Path("fake.wav"), confidence_threshold=0.6)
        assert result.flagged
        assert any(a.type == ArtifactType.LOW_CONFIDENCE for a in result.artifacts)

    @patch("vocal_qc.vocal_qc.load_whisper_model")
    @patch("vocal_qc.vocal_qc.get_audio_duration")
    def test_model_fallback_on_exception(self, mock_dur, mock_load):
        """If load_whisper_model raises, the test fixture controls it —
        real fallback is inside load_whisper_model itself."""
        mock_load.side_effect = RuntimeError("model failure")
        mock_dur.return_value = 2.0
        with pytest.raises(RuntimeError, match="model failure"):
            run_vocal_qc(Path("fake.wav"))


class TestWriteReport:
    def test_report_created(self, tmp_path: Path):
        result = run_vocal_qc.__wrapped__ if hasattr(run_vocal_qc, "__wrapped__") else None
        # Build a minimal result manually
        from vocal_qc import VocalQCResult
        res = VocalQCResult(
            track_name="test_track",
            transcript="hello world",
            words=[
                {"word": "hello", "start": 0.0, "end": 0.5, "confidence": 0.95},
                {"word": "world", "start": 0.6, "end": 1.1, "confidence": 0.92},
            ],
            artifacts=[],
            flagged=False,
            model_name="large-v3",
            processing_time_s=1.2,
        )
        out = tmp_path / "VOCAL_QC_REPORT.md"
        write_report(res, out)
        assert out.exists()
        text = out.read_text(encoding="utf-8")
        assert "test_track" in text
        assert "hello world" in text
        assert "No artifacts detected" in text

    def test_report_with_artifacts(self, tmp_path: Path):
        from vocal_qc import VocalQCResult, Artifact
        res = VocalQCResult(
            track_name="bad_track",
            transcript="hello uhh world",
            words=[
                {"word": "hello", "start": 0.0, "end": 0.5, "confidence": 0.95},
                {"word": "uhh", "start": 0.6, "end": 1.1, "confidence": 0.45},
                {"word": "world", "start": 4.0, "end": 4.5, "confidence": 0.92},
            ],
            artifacts=[
                Artifact(
                    type=ArtifactType.LOW_CONFIDENCE,
                    start=0.6,
                    end=1.1,
                    text="uhh",
                    details="confidence=0.45",
                ),
                Artifact(
                    type=ArtifactType.MISSING_BREATH,
                    start=1.1,
                    end=4.0,
                    text="",
                    details="gap=2.90s",
                ),
            ],
            flagged=True,
            model_name="large-v3",
            processing_time_s=2.0,
        )
        out = tmp_path / "VOCAL_QC_REPORT.md"
        write_report(res, out)
        text = out.read_text(encoding="utf-8")
        assert "low_confidence" in text
        assert "missing_breath" in text
        assert "YES" in text
