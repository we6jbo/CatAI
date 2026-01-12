#!/bin/bash
#Runs at catai user every 10min
# need to run /opt/cataised/hbwchat which connects to the T14.

FLAG_FILE="/tmp/fsadwadg.txt"
WAV_URL="https://www.kessels.com/CatSounds/cat2.wav"
WAV_PATH="/tmp/cat2.wav"

# If flag exists, exit
if [[ -f "$FLAG_FILE" ]]; then
  exit 0
fi

# Create flag file (one-time gate)
: > "$FLAG_FILE"

# Download wav
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$WAV_URL" -o "$WAV_PATH"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$WAV_PATH" "$WAV_URL"
else
  echo "ERROR: Need curl or wget to download $WAV_URL" >&2
  exit 1
fi

# Choose a player (prefer aplay)
if command -v aplay >/dev/null 2>&1; then
  aplay "$WAV_PATH"
elif command -v paplay >/dev/null 2>&1; then
  paplay "$WAV_PATH"
elif command -v ffplay >/dev/null 2>&1; then
  ffplay -nodisp -autoexit "$WAV_PATH"
else
  echo "ERROR: No audio player found. Install one of: alsa-utils (aplay), pulseaudio-utils (paplay), or ffmpeg (ffplay)." >&2
  exit 1
fi
