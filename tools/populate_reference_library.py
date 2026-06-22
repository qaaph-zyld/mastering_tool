"""Populate REFERENCE_LIBRARY.csv from mastered tracks in Distro Kidea.

Scans Music-AI-Toolshop/Distro Kidea for *_MASTER_32f.wav files, extracts
full metric rows matching the reference_benchmark.sh schema, and appends
to REFERENCE_LIBRARY.csv (creating it if missing).

Usage:
    python tools/populate_reference_library.py
"""
from __future__ import annotations

import csv
import os
import re
import subprocess
import sys
from pathlib import Path

# Path to portable ffmpeg
FFMPEG = Path("D:/Projects/ffmpeg_portable/ffmpeg-8.1.1-essentials_build/bin/ffmpeg.exe")
FFPROBE = Path("D:/Projects/ffmpeg_portable/ffmpeg-8.1.1-essentials_build/bin/ffprobe.exe")

DISTRO_DIR = Path("D:/Projects/Music-AI-Toolshop/Distro Kidea")
CSV_PATH = Path("D:/Projects/Music-AI-Toolshop/mastering_tool/REFERENCE_LIBRARY.csv")

HDR = (
    "name,sr,bits,duration_s,integrated_lufs,lra_lu,true_peak_dbtp,sample_peak_dbfs,"
    "rms_db,crest_db,plr_db,psr_db,max_momentary,max_short_term,st_p50,st_p90,st_p99,"
    "st_spread,corr_mean,corr_min,corr_max,lowband_corr_mean,lowband_corr_min,mono_loss_lu,"
    "peak_count_l,peak_count_r,flat_factor,dc_offset,b20_60,b60_120,b120_250,b250_500,"
    "b500_1k,b1k_2k,b2k_4k,b4k_8k,b8k_16k,b16k_up,hf14_16,hf16_18,hf18_20,hf20_22"
)


def run(cmd: list[str]) -> str:
    """Run a command and return stdout decoded, swallowing stderr."""
    result = subprocess.run(
        cmd, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    return result.stdout + result.stderr


def ffprobe_format(path: Path) -> tuple[int, int, int, float]:
    """Return (sample_rate, channels, bits, duration)."""
    out = run([
        str(FFPROBE), "-v", "error",
        "-select_streams", "a:0",
        "-show_entries", "stream=sample_rate,channels,bits_per_sample",
        "-show_entries", "format=duration",
        "-of", "csv=p=0", str(path)
    ])
    # Output like: 44100,2,16\n156.920454\n
    lines = [l.strip() for l in out.strip().splitlines() if l.strip()]
    if not lines:
        raise RuntimeError(f"ffprobe failed for {path}")
    # First line is stream info, last is duration
    stream_parts = lines[0].split(",")
    sr = int(stream_parts[0]) if stream_parts[0] else 0
    ch = int(stream_parts[1]) if len(stream_parts) > 1 and stream_parts[1] else 0
    bits = int(stream_parts[2]) if len(stream_parts) > 2 and stream_parts[2] else 0
    dur = float(lines[-1]) if len(lines) > 1 else 0.0
    return sr, ch, bits, dur


def ebur128(path: Path) -> tuple[float, float, float]:
    """Return (integrated_lufs, lra_lu, true_peak_dbtp).

    Parses the *summary* section of the ebur128 output to avoid
    picking up intermediate frame values.
    """
    out = run([
        str(FFMPEG), "-hide_banner", "-nostats", "-i", str(path),
        "-af", "ebur128=peak=true", "-f", "null", "-"
    ])
    # Split on "Summary:" and take the last chunk so we only parse the summary
    parts = out.split("Summary:")
    summary = parts[-1] if len(parts) > 1 else out

    i_match = re.search(r"I:\s+([-\d.]+)\s+LUFS", summary)
    lra_match = re.search(r"LRA:\s+([\d.]+)\s+LU", summary)
    tp_match = re.search(r"Peak:\s+([-\d.]+)\s+dBFS", summary)
    i_val = float(i_match.group(1)) if i_match else 0.0
    lra_val = float(lra_match.group(1)) if lra_match else 0.0
    tp_val = float(tp_match.group(1)) if tp_match else 0.0
    return i_val, lra_val, tp_val


def astats(path: Path) -> tuple[float, float, float, int, int, float]:
    """Return (sample_peak_dbfs, rms_db, dc_offset, peak_count_l, peak_count_r, flat_factor)."""
    out = run([
        str(FFMPEG), "-hide_banner", "-nostats", "-i", str(path),
        "-af",
        "astats=measure_perchannel=Peak_level+Peak_count+Flat_factor:measure_overall=Peak_level+RMS_level+DC_offset",
        "-f", "null", "-"
    ])
    # Overall peak
    spk_match = re.search(r"Peak level dB:\s+([-\d.]+)", out)
    rms_match = re.search(r"RMS level dB:\s+([-\d.]+)", out)
    dc_match = re.search(r"DC offset:\s+([-\d.eE+]+)", out)
    spk = float(spk_match.group(1)) if spk_match else 0.0
    rms = float(rms_match.group(1)) if rms_match else 0.0
    dc = float(dc_match.group(1)) if dc_match else 0.0

    # Per-channel peak count and flat factor
    # Channel blocks appear as "Channel: 1" then "Channel: 2"
    channels = re.findall(r"Channel:\s*\d+.*?(?=Channel:|$)", out, re.DOTALL)
    pkcnt_l = pkcnt_r = 0
    flat = 0.0
    for idx, block in enumerate(channels[:2]):
        pk_match = re.search(r"Peak count:\s+(\d+)", block)
        fl_match = re.search(r"Flat factor:\s+([\d.]+)", block)
        if pk_match:
            val = int(pk_match.group(1))
            if idx == 0:
                pkcnt_l = val
            else:
                pkcnt_r = val
        if fl_match and idx == 0:
            flat = float(fl_match.group(1))
    return spk, rms, dc, pkcnt_l, pkcnt_r, flat


def short_term_stats(path: Path) -> tuple[float, float, float, float]:
    """Return (p50, p90, p99, max) short-term LUFS values."""
    out = run([
        str(FFMPEG), "-hide_banner", "-nostats", "-i", str(path),
        "-af", "ebur128=metadata=1,ametadata=print:key=lavfi.r128.S:file=-",
        "-f", "null", "-"
    ])
    values = []
    for line in out.splitlines():
        m = re.search(r"lavfi\.r128\.S=(.+)", line)
        if m:
            v = float(m.group(1).strip())
            if v > -70:
                values.append(v)
    if not values:
        return 0.0, 0.0, 0.0, 0.0
    values.sort()
    n = len(values)
    p50 = values[int(n * 0.5)]
    p90 = values[int(n * 0.9)]
    p99 = values[int(n * 0.99)]
    vmax = values[-1]
    return p50, p90, p99, vmax


def momentary_max(path: Path) -> float:
    """Return max momentary LUFS."""
    out = run([
        str(FFMPEG), "-hide_banner", "-nostats", "-i", str(path),
        "-af", "ebur128=metadata=1,ametadata=print:key=lavfi.r128.M:file=-",
        "-f", "null", "-"
    ])
    mmax = None
    for line in out.splitlines():
        m = re.search(r"lavfi\.r128\.M=(.+)", line)
        if m:
            v = float(m.group(1).strip())
            if v > -70 and (mmax is None or v > mmax):
                mmax = v
    return mmax if mmax is not None else 0.0


def phase_corr(path: Path) -> tuple[float, float, float]:
    """Return (mean, min, max) phase correlation."""
    out = run([
        str(FFMPEG), "-hide_banner", "-nostats", "-i", str(path),
        "-af", "aphasemeter=video=0,ametadata=print:key=lavfi.aphasemeter.phase:file=-",
        "-f", "null", "-"
    ])
    vals = []
    mmin = mmax = None
    for line in out.splitlines():
        m = re.search(r"lavfi\.aphasemeter\.phase=(.+)", line)
        if m:
            v = float(m.group(1).strip())
            vals.append(v)
            if mmin is None or v < mmin:
                mmin = v
            if mmax is None or v > mmax:
                mmax = v
    if not vals:
        return 0.0, 0.0, 0.0
    return sum(vals) / len(vals), mmin, mmax


def lowband_corr(path: Path) -> tuple[float, float]:
    """Return (mean, min) low-band (<120 Hz) phase correlation."""
    out = run([
        str(FFMPEG), "-hide_banner", "-nostats", "-i", str(path),
        "-af", "lowpass=f=120,aphasemeter=video=0,ametadata=print:key=lavfi.aphasemeter.phase:file=-",
        "-f", "null", "-"
    ])
    vals = []
    mmin = None
    for line in out.splitlines():
        m = re.search(r"lavfi\.aphasemeter\.phase=(.+)", line)
        if m:
            v = float(m.group(1).strip())
            vals.append(v)
            if mmin is None or v < mmin:
                mmin = v
    if not vals:
        return 0.0, 0.0
    return sum(vals) / len(vals), mmin


def mono_loss(path: Path, stereo_i: float) -> float:
    """Return mono fold-down loss (R128 baseline-corrected)."""
    out = run([
        str(FFMPEG), "-hide_banner", "-nostats", "-i", str(path),
        "-af", "pan=mono|c0=0.5*c0+0.5*c1,ebur128", "-f", "null", "-"
    ])
    m_match = re.search(r"I:\s+([-\d.]+)\s+LUFS", out)
    if not m_match:
        return 0.0
    mono_i = float(m_match.group(1))
    return (stereo_i - mono_i) - 3.01


def band_rms(path: Path, filt: str) -> float:
    """Return RMS level dB for a given filter chain."""
    out = run([
        str(FFMPEG), "-hide_banner", "-nostats", "-i", str(path),
        "-af", f"{filt},astats=measure_overall=RMS_level:measure_perchannel=0",
        "-f", "null", "-"
    ])
    m = re.search(r"RMS level dB:\s+([-\d.]+)", out)
    return float(m.group(1)) if m else 0.0


def process_track(path: Path) -> list[str]:
    """Extract all metrics for one track and return a CSV row."""
    name = path.stem
    print(f"  Processing: {name}")

    sr, ch, bits, dur = ffprobe_format(path)
    i_lufs, lra, tp = ebur128(path)
    spk, rms, dc, pkcnt_l, pkcnt_r, flat = astats(path)
    st_p50, st_p90, st_p99, st_max = short_term_stats(path)
    m_max = momentary_max(path)

    plr = round(tp - i_lufs, 1)
    psr = round(tp - st_max, 1)
    crest = round(spk - rms, 1)
    st_spread = round(st_p99 - st_p50, 1)

    corr_mean, corr_min, corr_max = phase_corr(path)
    lb_mean, lb_min = lowband_corr(path)
    mono = mono_loss(path, i_lufs)

    # Octave bands
    bands = [
        band_rms(path, "highpass=f=20,lowpass=f=60"),
        band_rms(path, "highpass=f=60,lowpass=f=120"),
        band_rms(path, "highpass=f=120,lowpass=f=250"),
        band_rms(path, "highpass=f=250,lowpass=f=500"),
        band_rms(path, "highpass=f=500,lowpass=f=1000"),
        band_rms(path, "highpass=f=1000,lowpass=f=2000"),
        band_rms(path, "highpass=f=2000,lowpass=f=4000"),
        band_rms(path, "highpass=f=4000,lowpass=f=8000"),
        band_rms(path, "highpass=f=8000,lowpass=f=16000"),
        band_rms(path, "highpass=f=16000"),
    ]

    # HF probes
    hf = [
        band_rms(path, "highpass=f=14000,lowpass=f=16000"),
        band_rms(path, "highpass=f=16000,lowpass=f=18000"),
        band_rms(path, "highpass=f=18000,lowpass=f=20000"),
        band_rms(path, "highpass=f=20000,lowpass=f=22000"),
    ]

    row = [
        name, sr, bits, f"{dur:.6f}",
        f"{i_lufs:.1f}", f"{lra:.1f}", f"{tp:.1f}", f"{spk:.6f}",
        f"{rms:.6f}", f"{crest:.1f}", f"{plr:.1f}", f"{psr:.1f}",
        f"{m_max:.2f}", f"{st_max:.2f}", f"{st_p50:.2f}", f"{st_p90:.2f}",
        f"{st_p99:.2f}", f"{st_spread:.1f}",
        f"{corr_mean:.4f}", f"{corr_min:.4f}", f"{corr_max:.4f}",
        f"{lb_mean:.4f}", f"{lb_min:.4f}", f"{mono:.1f}",
        pkcnt_l, pkcnt_r, f"{flat:.1f}", f"{dc:.6f}",
    ]
    row += [f"{b:.1f}" for b in bands]
    row += [f"{h:.1f}" for h in hf]
    return [str(x) for x in row]


def main() -> int:
    tracks = sorted(DISTRO_DIR.glob("*_MASTER_32f.wav"))
    if not tracks:
        print(f"No *_MASTER_32f.wav files found in {DISTRO_DIR}")
        return 1

    print(f"Found {len(tracks)} mastered tracks in {DISTRO_DIR}")

    # Read existing rows to avoid duplicates
    existing_names: set[str] = set()
    if CSV_PATH.exists():
        with open(CSV_PATH, "r", newline="", encoding="utf-8") as f:
            reader = csv.reader(f)
            try:
                next(reader)  # skip header
            except StopIteration:
                pass
            for row in reader:
                if row:
                    existing_names.add(row[0])
        print(f"  Existing library has {len(existing_names)} entries")

    # Ensure header
    if not CSV_PATH.exists():
        with open(CSV_PATH, "w", newline="", encoding="utf-8") as f:
            f.write(HDR + "\n")
        print(f"  Created {CSV_PATH} with header")

    new_count = 0
    with open(CSV_PATH, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, lineterminator="\n")
        for track in tracks:
            name = track.stem
            if name in existing_names:
                print(f"  SKIP (already in library): {name}")
                continue
            try:
                row = process_track(track)
                writer.writerow(row)
                new_count += 1
                print(f"  ADDED: {name}")
            except Exception as exc:
                print(f"  ERROR processing {name}: {exc}")
                continue

    print(f"\nDone. Added {new_count} new references. Total in library: {len(existing_names) + new_count}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
