"""Vocal Doctor — rule-based vocal diagnosis and chain recommendation."""

from .diagnose import diagnose_vocal
from .recommend import VocalRecommendation, diagnose_and_recommend, recommend_chain

__all__ = ["diagnose_vocal", "VocalRecommendation", "diagnose_and_recommend", "recommend_chain"]
