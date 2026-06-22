"""CLAP reference matching for mastering_tool.

Match mastered tracks against a reference library using
Contrastive Language-Audio Pretraining embeddings.
"""

from .clap_matcher import (
    run_clap_match,
    CLAPMatchResult,
    MatchResult,
    ReferenceEntry,
    cosine_similarity,
    load_reference_library,
    match_track,
)

__all__ = [
    "run_clap_match",
    "CLAPMatchResult",
    "MatchResult",
    "ReferenceEntry",
    "cosine_similarity",
    "load_reference_library",
    "match_track",
]
