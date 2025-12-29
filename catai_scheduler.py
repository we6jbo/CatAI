#!/usr/bin/env python3
import os
import time
import random
import signal
import subprocess
from datetime import datetime, date, timedelta
from pathlib import Path

# ---- CONFIG ----
TIMES = [
    "05:35",
    "07:00", "07:20", "07:30",
    "08:00", "08:45",
    "09:00", "09:10", "09:15", "09:20", "09:40",
    "10:00", "10:05", "10:25", "10:35", "10:55",
    "11:15", "11:25", "11:55",
    "13:00",
    "14:00", "14:10", "14:30",
    "15:00", "15:15", "15:45",
    "16:15",
    "20:00",
]
JITTER_SECONDS = 10 * 60  # +/- 10 minutes

# Primary: downloaded files
ASSETS_DIR = Path(os.environ.get("CATAI_ASSETS_DIR", str(Path.home() / "private-assets")))

# Fallback: repo sounds
REPO_SOUNDS_DIR = Path(os.environ.get("CATAI_SOUNDS_DIR", str(Path(__file__).resolve().parent / "sounds")))

# Optional ALSA device (mostly relevant for aplay; mpg123 usually works without it)
ALSA_DEVICE = os.environ.get("CATAI_ALSA_DEVICE", "").strip()
# ----------------

_running = True

def _handle_stop(signum, frame):
    global _running
    _running = False

signal.signal(signal.SIGTERM, _handle_stop)
signal.signal(signal.SIGINT, _handle_stop)

def log(msg: str) -> None:
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)

def _list_audio_files(d: Path):
    if not d.exists() or not d.is_dir():
        return []
    out = []
    for p in d.iterdir():
        if p.is_file() and p.suffix.lower() in [".mp3", ".wav", ".ogg"]:
            out.append(p)
    return sorted(out)

def pick_random_audio() -> Path | None:
    # Prefer private-assets
    assets = _list_audio_files(ASSETS_DIR)
    if assets:
        return random.choice(assets)

    # Fallback to repo sounds
    sounds = _list_audio_files(REPO_SOUNDS_DIR)
    if sounds:
        return random.choice(sounds)

    return None

def play_audio(path: Path) -> None:
    ext = path.suffix.lower()

    # MP3
    if ext == ".mp3":
        # mpg123 is lightweight and reliable on Pi
        cmd = ["mpg123", "-q", str(path)]
        log(f"Playing MP3: {path.name}")
        subprocess.run(cmd, check=False)
        return

    # WAV/OGG fallback
    if ext == ".wav":
        cmd = ["aplay", str(path)] if not ALSA_DEVICE else ["aplay", "-D", ALSA_DEVICE, str(path)]
        log(f"Playing WAV: {path.name}")
        subprocess.run(cmd, check=False)
        return

    if ext == ".ogg":
        # requires vorbis-tools (ogg123). If not installed, it will just fail gracefully.
        cmd = ["ogg123", "-q", str(path)]
        log(f"Playing OGG: {path.name}")
        subprocess.run(cmd, check=False)
        return

    log(f"Unsupported file type: {path}")

def build_today_schedule(seed: int):
    today = date.today()
    rnd = random.Random(seed)
    schedule = []
    for t in TIMES:
        hh, mm = t.split(":")
        base = datetime(today.year, today.month, today.day, int(hh), int(mm), 0)
        jitter = rnd.randint(-JITTER_SECONDS, JITTER_SECONDS)
        schedule.append(base + timedelta(seconds=jitter))
    schedule.sort()
    return schedule

def seconds_until(dt: datetime) -> float:
    return max(0.0, (dt - datetime.now()).total_seconds())

def main():
    log("CatAI scheduler starting (mp3-capable).")
    log(f"ASSETS_DIR={ASSETS_DIR}")
    log(f"REPO_SOUNDS_DIR={REPO_SOUNDS_DIR}")

    while _running:
        today_seed = int(date.today().strftime("%Y%m%d"))
        schedule = build_today_schedule(today_seed)

        now = datetime.now()
        pending = [dt for dt in schedule if dt > now]

        if not pending:
            # sleep until just after midnight
            tomorrow = datetime(now.year, now.month, now.day) + timedelta(days=1, seconds=2)
            sleep_s = seconds_until(tomorrow)
            log(f"No pending events left today. Sleeping {int(sleep_s)}s until tomorrow.")
            # sleep in chunks for responsiveness
            while _running and sleep_s > 0:
                chunk = min(sleep_s, 60.0)
                time.sleep(chunk)
                sleep_s = seconds_until(tomorrow)
            continue

        for dt in pending:
            if not _running:
                break

            sleep_s = seconds_until(dt)
            log(f"Next sound at {dt.strftime('%H:%M:%S')} (sleep {int(sleep_s)}s)")
            while _running and sleep_s > 0:
                chunk = min(sleep_s, 30.0)
                time.sleep(chunk)
                sleep_s = seconds_until(dt)

            if not _running:
                break

            choice = pick_random_audio()
            if choice is None:
                log("No audio files found in ~/private-assets or ./sounds; skipping.")
                continue

            play_audio(choice)

    log("CatAI scheduler stopping.")

if __name__ == "__main__":
    main()
