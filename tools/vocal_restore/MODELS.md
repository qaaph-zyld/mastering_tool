# Vocal Restoration Model Reference

Reference table for the neural restoration stages used in the vocal chain.

| Stage | Library | Model / Checkpoint | License | Size | GPU Runtime | CPU Runtime | Notes |
|---|---|---|---|---|---|---|---|
| DeepFilterNet3 | `deepfilternet` | `deepfilternet3` | Apache-2.0 | ~20 MB | ~0.3× RT | ~2× RT | Real-time; good for de-room and breath-gate recovery |
| VoiceFixer | `voicefixer` | Universal + Mode 0/1/2 | MIT | ~180 MB | ~1.5× RT | ~8× RT | Mode 2 (TTS-like) is the SUNO default |
| Apollo | `JusperLee/Apollo` | `Apollo` (Sony) | Apache-2.0 | ~400 MB | ~2× RT | ~15× RT | Best on codec-smearing / HF wash artifacts |
| AudioSR | `audiosr` | `audiosr-48k` | MIT | ~1.2 GB | ~4× RT | ~30× RT | Optional 48 kHz bandwidth extension; off by default |

*RT = real-time factor.  A 3-minute track at 2× RT takes ~1.5 minutes on GPU.*

## Installation Quick Reference

```bash
# Core + PyTorch
pip install numpy soundfile librosa tqdm
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu121

# Stages (install only what you need)
pip install deepfilternet
pip install voicefixer
pip install git+https://github.com/JusperLee/Apollo.git
# pip install audiosr   # optional
```

## Troubleshooting

- **CUDA out of memory**: Apollo and AudioSR are the heaviest. Run one stage at a time, or fall back to CPU.
- **VoiceFixer mode 2 sounds over-processed**: Try mode 1 (noisy) or mode 0 (clean) and A/B.
- **DeepFilterNet3 removes too much room**: Increase the `--attenuation-limit` if the CLI exposes it, or skip the stage (set `VR_DEROOM=0`).
