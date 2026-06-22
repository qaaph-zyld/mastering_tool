#!/bin/bash
# Octave-band spectral energy analysis (robust array version)
SOURCE="$1"
if [ -z "$SOURCE" ]; then echo "Usage: $0 <source.wav>"; exit 1; fi

labels=(
  "20-60Hz subbass"
  "60-120Hz bass"
  "120-250Hz lowmid"
  "250-500Hz mid"
  "500-1k mid"
  "1k-2k upmid"
  "2k-4k presence"
  "4k-8k brilliance"
  "8k-16k air"
  "16k+ ultra"
)
filters=(
  "highpass=f=20,lowpass=f=60"
  "highpass=f=60,lowpass=f=120"
  "highpass=f=120,lowpass=f=250"
  "highpass=f=250,lowpass=f=500"
  "highpass=f=500,lowpass=f=1000"
  "highpass=f=1000,lowpass=f=2000"
  "highpass=f=2000,lowpass=f=4000"
  "highpass=f=4000,lowpass=f=8000"
  "highpass=f=8000,lowpass=f=16000"
  "highpass=f=16000"
)

echo "=== OCTAVE-BAND SPECTRAL ENERGY ==="
for i in "${!labels[@]}"; do
    label="${labels[$i]}"
    filter="${filters[$i]}"
    rms=$(ffmpeg -hide_banner -nostats -i "$SOURCE" \
        -af "${filter},astats=measure_overall=RMS_level:measure_perchannel=0" \
        -f null - 2>&1 | grep "RMS level dB" | head -1 | awk -F: '{print $NF}' | tr -d ' \r')
    printf "  %-22s : %10s dB\n" "$label" "$rms"
done
