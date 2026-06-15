#!/usr/bin/env python3
# ============================================================
# matchering_xcheck.py  —  reference cross-check (DIAGNOSTIC ONLY)
# ------------------------------------------------------------
# Matchering is deterministic DSP matching, NOT a master path. Used
# here purely as a calibration cross-check: it matches your master
# toward a world-class reference, and the resulting tonal delta
# (matched - your_master) reveals where your tonal balance differs
# from the reference. Never ship the matched file; read the delta.
#
# Usage: python3 matchering_xcheck.py <your_master.wav> <reference.wav> [prefix]
# ============================================================
import sys, os, numpy as np, soundfile as sf
import logging
import matchering as mg
mg.log(warning_handler=lambda *a, **k: None)  # quiet
logging.getLogger("matchering").setLevel(logging.ERROR)

def main():
    if len(sys.argv) < 3:
        print("Usage: matchering_xcheck.py <your_master.wav> <reference.wav> [prefix]"); sys.exit(1)
    target, ref = sys.argv[1], sys.argv[2]
    prefix = sys.argv[3] if len(sys.argv) > 3 else "xcheck"
    matched = f"{prefix}_matched.wav"
    mg.process(target=target, reference=ref,
               results=[mg.pcm24(matched)])

    # tonal delta: matched - your_master  => the moves needed to reach the reference
    from scipy.signal import welch
    def ltas(p, nfft=8192):
        x, fs = sf.read(p); x = x.mean(1) if x.ndim>1 else x
        f, pw = welch(x, fs=fs, nperseg=nfft, noverlap=nfft//2, scaling="spectrum")
        return f, pw
    centres = np.array([31.5,63,125,250,500,1000,2000,4000,8000,16000.0])
    def bands(f, pw):
        out=[]
        for fc in centres:
            m=(f>=fc/2**(1/6))&(f<fc*2**(1/6))
            out.append(10*np.log10(pw[m].sum()+1e-20) if m.any() else np.nan)
        return np.array(out)
    fm,pm=ltas(matched); ft,pt=ltas(target)
    bm,bt=bands(fm,pm),bands(ft,pt)
    i1k=int(np.argmin(np.abs(centres-1000))); bm-=bm[i1k]; bt-=bt[i1k]
    d=bm-bt
    print(f"\nTonal moves Matchering applied to reach the reference (octave bands):")
    print(f"{'Hz':>8} {'delta_dB':>9}")
    for fc,dd in zip(centres,d):
        flag = "  <- your master is " + ("LIGHT here" if dd>0 else "HEAVY here") if abs(dd)>=2 else ""
        print(f"{fc:>8.0f} {dd:>9.1f}{flag}")
    print("\n(positive delta => reference has more energy there than you => you are light in that band)")
    print(f"NOTE: {matched} is a DIAGNOSTIC artifact, not a deliverable.")

if __name__ == "__main__":
    main()
