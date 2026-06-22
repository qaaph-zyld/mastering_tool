"""Tests for clap_matcher — mocked CLAP model, no HuggingFace download."""
from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch

import numpy as np
import pytest

from clap_matcher import (
    CLAPMatchResult,
    MatchResult,
    cosine_similarity,
    load_reference_library,
    match_track,
    run_clap_match,
)


class TestCosineSimilarity:
    def test_identical_vectors(self):
        a = np.array([[1.0, 0.0, 0.0]])
        b = np.array([[1.0, 0.0, 0.0]])
        assert cosine_similarity(a, b) == pytest.approx(1.0, abs=1e-6)

    def test_orthogonal_vectors(self):
        a = np.array([[1.0, 0.0, 0.0]])
        b = np.array([[0.0, 1.0, 0.0]])
        assert cosine_similarity(a, b) == pytest.approx(0.0, abs=1e-6)

    def test_opposite_vectors(self):
        a = np.array([[1.0, 0.0, 0.0]])
        b = np.array([[-1.0, 0.0, 0.0]])
        assert cosine_similarity(a, b) == pytest.approx(-1.0, abs=1e-6)


class TestLoadReferenceLibrary:
    def test_loads_csv(self, tmp_path: Path):
        csv = tmp_path / "test_library.csv"
        csv.write_text(
            "name,sr,bits,duration_s,integrated_lufs\n"
            "Track_A,44100,16,120.0,-8.0\n"
            "Track_B,48000,24,180.0,-10.0\n",
            encoding="utf-8",
        )
        entries = load_reference_library(csv)
        assert len(entries) == 2
        assert entries[0].name == "Track_A"
        assert entries[0].metadata["integrated_lufs"] == "-8.0"
        assert entries[1].name == "Track_B"

    def test_empty_csv(self, tmp_path: Path):
        csv = tmp_path / "empty.csv"
        csv.write_text(
            "name,sr,bits,duration_s,integrated_lufs\n",
            encoding="utf-8",
        )
        entries = load_reference_library(csv)
        assert len(entries) == 0

    def test_missing_file_raises(self):
        with pytest.raises(FileNotFoundError):
            load_reference_library(Path("nonexistent.csv"))


class TestMatchTrack:
    def test_ranks_by_similarity(self):
        from clap_matcher import ReferenceEntry

        entries = [
            ReferenceEntry(name="A", path=Path("a.wav"), embedding=np.array([[1.0, 0.0, 0.0]])),
            ReferenceEntry(name="B", path=Path("b.wav"), embedding=np.array([[0.9, 0.1, 0.0]])),
            ReferenceEntry(name="C", path=Path("c.wav"), embedding=np.array([[0.0, 1.0, 0.0]])),
        ]
        model = MagicMock()
        processor = MagicMock()

        with patch("clap_matcher.clap_matcher.load_audio") as mock_load:
            with patch("clap_matcher.clap_matcher.compute_embedding") as mock_emb:
                mock_load.return_value = np.zeros(100)
                # Track embedding closer to A than B or C
                mock_emb.return_value = np.array([[0.95, 0.05, 0.0]])
                matches = match_track(
                    Path("track.wav"), entries, model, processor, top_k=2
                )
        assert len(matches) == 2
        assert matches[0].name == "A"
        assert matches[0].similarity > matches[1].similarity

    def test_skips_missing_embeddings(self):
        from clap_matcher import ReferenceEntry

        entries = [
            ReferenceEntry(name="A", path=Path("a.wav"), embedding=np.array([[1.0, 0.0, 0.0]])),
            ReferenceEntry(name="B", path=Path("b.wav"), embedding=None),
        ]
        model = MagicMock()
        processor = MagicMock()

        with patch("clap_matcher.clap_matcher.load_audio") as mock_load:
            with patch("clap_matcher.clap_matcher.compute_embedding") as mock_emb:
                mock_load.return_value = np.zeros(100)
                mock_emb.return_value = np.array([[1.0, 0.0, 0.0]])
                matches = match_track(
                    Path("track.wav"), entries, model, processor, top_k=5
                )
        assert len(matches) == 1
        assert matches[0].name == "A"


class TestRunClapMatch:
    @patch("clap_matcher.clap_matcher.load_clap_model")
    @patch("clap_matcher.clap_matcher.load_audio")
    @patch("clap_matcher.clap_matcher.compute_embedding")
    def test_pipeline(
        self, mock_emb, mock_load_audio, mock_load_model
    ):
        mock_model = MagicMock()
        mock_processor = MagicMock()
        mock_load_model.return_value = (mock_model, mock_processor)
        mock_load_audio.return_value = np.zeros(100)
        # All calls return the same embedding (track similar to ref A)
        mock_emb.return_value = np.array([[0.95, 0.05]])

        csv = Path("D:/Projects/Music-AI-Toolshop/mastering_tool/REFERENCE_LIBRARY.csv")
        result = run_clap_match(
            Path("D:/Projects/Music-AI-Toolshop/Distro Kidea/10_outta_10_MASTER_32f.wav"),
            library_csv=csv,
            top_k=2,
            force_recompute=True,
        )
        assert result.track_name == "10_outta_10_MASTER_32f"
        assert len(result.top_matches) <= 2

    @patch("clap_matcher.clap_matcher.load_clap_model")
    def test_model_load_failure(self, mock_load):
        mock_load.side_effect = RuntimeError("model failure")
        with pytest.raises(RuntimeError, match="model failure"):
            run_clap_match(
                Path("fake.wav"),
                library_csv=Path("fake.csv"),
            )
