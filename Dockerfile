FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    python3 \
    python3-pip \
    bash \
    sox \
    libsox-fmt-all \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY ui/requirements.txt /app/ui/requirements.txt
RUN pip3 install --break-system-packages -r /app/ui/requirements.txt

# Copy pipeline scripts
WORKDIR /app
COPY *.sh /app/
COPY ui/ /app/ui/

# Create directories for audio processing
RUN mkdir -p /app/music_tracks/raw_wav_files/master \
    /app/music_tracks/raw_wav_files/intermediate \
    /app/music_tracks/raw_wav_files/analysis \
    /app/music_tracks/raw_wav_files/verification

# Expose Flask port
EXPOSE 5050

# Run the web UI
CMD ["python3", "/app/ui/server.py"]
