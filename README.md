## CatAI scheduler (MP3 capable)

Plays random audio at configured times with ±10 min daily jitter.

Audio sources (in priority order):
1) ~/private-assets (downloaded MP3s)
2) ./sounds (repo fallback)

### Install (Raspberry Pi OS)
sudo apt-get update
sudo apt-get install -y python3 python3-venv mpg123 alsa-utils

python3 -m venv .venv
./.venv/bin/python catai_scheduler.py
