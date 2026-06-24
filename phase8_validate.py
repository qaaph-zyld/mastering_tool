#!/usr/bin/env python3
"""Phase 8 end-to-end validation chain for a single input track.

This script replicates `vocal_restore.sh` in pure Python so it can run on the
Windows `.venv` Python. It performs, in order:

  1. Stem separation via open_DAW `ai_modules.stem_extractor`
  2. Vocal restoration (VoiceFixer by default; DeepFilterNet off)
  3. Re-mix restored vocal + instrumental
  4. Vocal QC (faster-whisper)
  5. Vocal Doctor diagnosis + chain recommendation
  6. Render the recommended chain via pedalboard
  7. CLAP reference matching against REFERENCE_LIBRARY.csv

Usage:
    python phase8_validate.py <input.mp3_or_wav> <output_dir>
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
import warnings
from pathlib import Path

# HuggingFace hub tries to create symlinks on Windows by default; this fails on
# non-developer-mode Windows and causes model loads to fall back to larger,
# slower models. Disable symlinks before any HF library imports.
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS", "1")
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")

# Add open_DAW and the umbrella repo to PYTHONPATH so the stem extractor and
# toolshop.voice_effects_adapter can be imported.
ROOT = Path(__file__).resolve().parent
UMBRELLA = ROOT.parent
OPEN_DAW = UMBRELLA / "open_DAW"
sys.path.insert(0, str(OPEN_DAW))
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(UMBRELLA))

import numpy as np
import soundfile as sf

# Internal logging so the script can be run from any shell and still capture all
# stdout/stderr. Log file is placed next to the output directory.
_LOG_FILE: Path | None = None


def _start_logging(output_dir: Path) -> None:
    global _LOG_FILE
    log_dir = Path(output_dir).parent
    log_dir.mkdir(parents=True, exist_ok=True)
    _LOG_FILE = log_dir / f"{Path(output_dir).name}_validation.log"
    sys.stdout = _Tee(sys.stdout, _LOG_FILE, mode="stdout")
    sys.stderr = _Tee(sys.stderr, _LOG_FILE, mode="stderr")
    print(f"Logging to {_LOG_FILE}")


class _Tee:
    def __init__(self, stream, log_path: Path, mode: str):
        self.stream = stream
        self.log_path = log_path
        self.mode = mode
        self._log = open(log_path, "a", encoding="utf-8", errors="replace")

    def write(self, data: str) -> int:
        self._log.write(data)
        self._log.flush()
        return self.stream.write(data)

    def flush(self) -> None:
        self._log.flush()
        self.stream.flush()

    def __getattr__(self, name: str):
        return getattr(self.stream, name)

    def __del__(self):
        self._log.close()

# ---------------------------------------------------------------------------
# Imports from the open_DAW / mastering_tool packages
# ---------------------------------------------------------------------------

from ai_modules.stem_extractor.separator import separate  # noqa: E402

from mastering_tool.tools.vocal_restore.restore import restore  # noqa: E402
from mastering_tool.tools.vocal_restore.remix import remix  # noqa: E402
from mastering_tool.tools.vocal_qc.vocal_qc import run_vocal_qc, write_report as write_qc_report  # noqa: E402
from mastering_tool.tools.vocal_doctor.recommend import diagnose_and_recommend  # noqa: E402
from mastering_tool.tools.chain_dsl.executors.pedalboard_exec import render_file as render_pedalboard  # noqa: E402
from mastering_tool.tools.chain_dsl.executors.masterbus_exec import render_json as render_chain_json  # noqa: E402
from mastering_tool.tools.clap_matcher.clap_matcher import run_clap_match, write_report as write_clap_report  # noqa: E402


def run_chain(input_path: Path, output_dir: Path, restore_stages: list[str] | None = None) -> dict:
    """Run the full Phase 8 validation chain on one input file."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    basename = input_path.stem

    timings: dict[str, float] = {}

    # ------------------------------------------------------------------
    # 1. Stem separation (vocals only, derive instrumental by subtraction)
    # ------------------------------------------------------------------
    print(f"\n[1/7] Stem separation: {input_path.name}")
    t0 = time.time()
    # Use only the vocals model to avoid the heavy second RoFormer model load.
    stems = separate(input_path, stems=["vocals"], backend=None)
    vocal_stem = stems["vocals"]
    timings["stem_separation"] = time.time() - t0
    print(f"  vocal stem: {vocal_stem}")

    # Copy vocal stem into the output dir.
    local_vocal = output_dir / f"{basename}_vocal.wav"
    shutil.copy(vocal_stem, local_vocal)

    # Derive instrumental = mix - vocal (same sample rate and length).
    print("  deriving instrumental by subtraction")
    local_inst = output_dir / f"{basename}_instrumental.wav"
    mix, sr_mix = sf.read(str(input_path), dtype="float32")
    if mix.ndim == 1:
        mix = mix[:, None]
    vocal, sr_vocal = sf.read(str(local_vocal), dtype="float32")
    if vocal.ndim == 1:
        vocal = vocal[:, None]
    if sr_mix != sr_vocal:
        import librosa

        vocal = librosa.resample(vocal.T, orig_sr=sr_vocal, target_sr=sr_mix).T
    # Match length to the shortest.
    n = min(mix.shape[0], vocal.shape[0])
    mix = mix[:n]
    vocal = vocal[:n]
    # If vocal is mono and mix is stereo, duplicate mono to stereo.
    if vocal.shape[1] == 1 and mix.shape[1] == 2:
        vocal = np.repeat(vocal, 2, axis=1)
    inst = mix - vocal
    sf.write(str(local_inst), inst, sr_mix, subtype="FLOAT")

    # ------------------------------------------------------------------
    # 2. Vocal restoration
    # ------------------------------------------------------------------
    print(f"\n[2/7] Vocal restoration: stages={restore_stages or ['voicefixer']}")
    restored_vocal = output_dir / f"{basename}_vocal_restored.wav"
    t0 = time.time()
    restore(local_vocal, restored_vocal, stages=restore_stages)
    timings["vocal_restoration"] = time.time() - t0

    # ------------------------------------------------------------------
    # 3. Re-mix
    # ------------------------------------------------------------------
    print(f"\n[3/7] Re-mix")
    remixed = output_dir / f"{basename}_restored_full_mix.wav"
    t0 = time.time()
    # The instrumental is derived from the original mix; the restored vocal may
    # have a different sample rate (e.g., VoiceFixer works at 44100 Hz). Resample
    # the restored vocal to the instrumental's rate so remix can sum them.
    v_data, sr_v = sf.read(str(restored_vocal), dtype="float32")
    i_data, sr_i = sf.read(str(local_inst), dtype="float32")
    if sr_v != sr_i:
        import librosa

        v_data = librosa.resample(v_data.T, orig_sr=sr_v, target_sr=sr_i).T
        restored_vocal_sr = output_dir / f"{basename}_vocal_restored_{sr_i}.wav"
        sf.write(str(restored_vocal_sr), v_data, sr_i, subtype="FLOAT")
        restored_vocal = restored_vocal_sr
    remix(restored_vocal, local_inst, remixed, gain_match="lufs")
    timings["remix"] = time.time() - t0

    # ------------------------------------------------------------------
    # 4. Vocal QC
    # ------------------------------------------------------------------
    print(f"\n[4/7] Vocal QC")
    qc_report = output_dir / "VOCAL_QC_REPORT.md"
    t0 = time.time()
    qc_result = run_vocal_qc(restored_vocal, model_size="base.en", compute_type="int8")
    write_qc_report(qc_result, qc_report)
    timings["vocal_qc"] = time.time() - t0
    print(f"  flagged: {qc_result.flagged}, artifacts: {len(qc_result.artifacts)}")

    # ------------------------------------------------------------------
    # 5. Vocal Doctor
    # ------------------------------------------------------------------
    print(f"\n[5/7] Vocal Doctor")
    t0 = time.time()
    doctor_result = diagnose_and_recommend(restored_vocal)
    chain_json = output_dir / "chain.json"
    from mastering_tool.tools.chain_dsl.schema import Chain  # noqa: E402

    chain = Chain.from_dict(doctor_result["chain"])
    render_chain_json(chain, chain_json)
    doctor_json = output_dir / "vocal_doctor.json"
    doctor_json.write_text(json.dumps(doctor_result, indent=2), encoding="utf-8")
    timings["vocal_doctor"] = time.time() - t0
    print(f"  recommendations: {len(doctor_result['recommendations'])}")
    print(f"  chain.json: {chain_json}")

    # ------------------------------------------------------------------
    # 6. Render chain via pedalboard
    # ------------------------------------------------------------------
    print(f"\n[6/7] Render chain via pedalboard")
    t0 = time.time()
    rendered_chain = output_dir / f"{basename}_chain_rendered.wav"
    render_pedalboard(chain, remixed, rendered_chain)
    timings["pedalboard_render"] = time.time() - t0

    # ------------------------------------------------------------------
    # 7. CLAP reference match
    # ------------------------------------------------------------------
    print(f"\n[7/7] CLAP reference match")
    t0 = time.time()
    clap_report = output_dir / "CLAP_MATCH_REPORT.md"
    clap_result = run_clap_match(
        track_path=rendered_chain,
        library_csv=Path(
            os.environ.get(
                "REFERENCE_LIBRARY_CSV",
                "D:/Projects/Music-AI-Toolshop/mastering_tool/REFERENCE_LIBRARY.csv",
            )
        ),
        top_k=5,
        device="cpu",
        model_name="laion/clap-htsat-fused",
        force_recompute=False,
    )
    write_clap_report(clap_result, clap_report)
    timings["clap_match"] = time.time() - t0
    print(f"  top match: {clap_result.top_matches[0].name if clap_result.top_matches else 'N/A'}")

    return {
        "input": str(input_path),
        "output_dir": str(output_dir),
        "basename": basename,
        "timings": timings,
        "qc_flagged": qc_result.flagged,
        "qc_artifacts": len(qc_result.artifacts),
        "recommendations": len(doctor_result["recommendations"]),
        "top_match": clap_result.top_matches[0].name if clap_result.top_matches else None,
        "top_similarity": clap_result.top_matches[0].similarity if clap_result.top_matches else None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Phase 8 validation chain")
    parser.add_argument("input", type=Path, help="Input audio file (mp3 or wav)")
    parser.add_argument("output_dir", type=Path, help="Output directory for artifacts")
    parser.add_argument(
        "--restore-stages",
        nargs="+",
        default=["voicefixer"],
        help="Restoration stages to run (default: voicefixer)",
    )
    args = parser.parse_args()

    if not args.input.exists():
        print(f"ERROR: input not found: {args.input}", file=sys.stderr)
        return 1

    _start_logging(args.output_dir)

    result = run_chain(args.input, args.output_dir, restore_stages=args.restore_stages)
    summary_path = Path(args.output_dir) / "phase8_summary.json"
    summary_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"\nPhase 8 complete. Summary: {summary_path}")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
