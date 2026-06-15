#!/usr/bin/env python3
# ============================================================
# tonal_delta.py  —  1/3-octave LTAS tonal-balance delta
# ------------------------------------------------------------
# Computes the long-term average spectrum (Welch) of a master and
# a reference in 1/3-octave bands and reports the per-band delta
# (master - reference) in dB. Feeds the "tonal-delta in report"
# requirement: a numeric tonal-balance north star vs a reference.
#
# Usage:
#   python3 tonal_delta.py <master.wav> <reference.wav> [out_prefix]
# Outputs:
#   <prefix>_tonal_delta.txt   table
#   <prefix>_tonal_delta.png   overlay + delta plot
# ============================================================
import sys, numpy as np, soundfile as sf
from scipy.signal import welch
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

def ltas(path, nfft=8192):
    x, fs = sf.read(path)
    if x.ndim > 1:
        x = x.mean(axis=1)            # mono sum for tonal balance
    f, p = welch(x, fs=fs, nperseg=nfft, noverlap=nfft//2, scaling="spectrum")
    return f, p

# 1/3-octave centres (ISO), 25 Hz .. 20 kHz
centres = np.array([25,31.5,40,50,63,80,100,125,160,200,250,315,400,500,630,800,
                    1000,1250,1600,2000,2500,3150,4000,5000,6300,8000,10000,12500,16000,20000.0])

def band_levels(f, p):
    out = []
    for fc in centres:
        lo, hi = fc/2**(1/6), fc*2**(1/6)
        m = (f >= lo) & (f < hi)
        out.append(10*np.log10(p[m].sum()+1e-20) if m.any() else np.nan)
    return np.array(out)

def main():
    if len(sys.argv) < 3:
        print("Usage: tonal_delta.py <master.wav> <reference.wav> [out_prefix]"); sys.exit(1)
    master, ref = sys.argv[1], sys.argv[2]
    prefix = sys.argv[3] if len(sys.argv) > 3 else "tonal"
    fm, pm = ltas(master); fr, pr = ltas(ref)
    bm, br = band_levels(fm, pm), band_levels(fr, pr)
    # normalize both to 0 dB at 1 kHz so the comparison is about *balance*, not level
    i1k = int(np.argmin(np.abs(centres-1000)))
    bm -= bm[i1k]; br -= br[i1k]
    delta = bm - br

    with open(f"{prefix}_tonal_delta.txt", "w") as fo:
        hdr = f"{'band(Hz)':>10} {'master':>8} {'ref':>8} {'delta':>8}"
        print(hdr); fo.write(hdr+"\n")
        for fc, m, r, d in zip(centres, bm, br, delta):
            flag = "  <<" if abs(d) >= 3 else ""
            line = f"{fc:>10.0f} {m:>8.1f} {r:>8.1f} {d:>8.1f}{flag}"
            print(line); fo.write(line+"\n")
    print(f"\n(delta = master - ref, both normalized to 0 dB @1k; '<<' = |delta|>=3 dB)")

    fig, (a1, a2) = plt.subplots(2, 1, figsize=(11, 7), sharex=True)
    a1.semilogx(centres, bm, "-o", ms=3, label="master")
    a1.semilogx(centres, br, "-o", ms=3, label="reference")
    a1.set_ylabel("dB (norm @1k)"); a1.legend(); a1.grid(True, which="both", alpha=.3)
    a1.set_title("1/3-octave LTAS — master vs reference")
    a2.semilogx(centres, delta, "-o", ms=3, color="darkorange")
    a2.axhline(0, color="k", lw=.6); a2.axhline(3, color="r", ls=":", lw=.6); a2.axhline(-3, color="r", ls=":", lw=.6)
    a2.set_ylabel("delta dB"); a2.set_xlabel("Hz"); a2.grid(True, which="both", alpha=.3)
    a2.set_title("tonal delta (master - reference)")
    plt.tight_layout(); plt.savefig(f"{prefix}_tonal_delta.png", dpi=110)
    print(f"\nwrote {prefix}_tonal_delta.txt and {prefix}_tonal_delta.png")

if __name__ == "__main__":
    main()
