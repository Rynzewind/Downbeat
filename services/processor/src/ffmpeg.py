from pathlib import Path
import subprocess

from .models import Artifact


def build_mp3_command(source: Path, destination: Path) -> list[str]:
    return ["ffmpeg", "-nostdin", "-y", "-i", str(source), "-vn", "-codec:a", "libmp3lame", "-q:a", "2", str(destination)]


def convert_audio_to_mp3(source: Path, destination: Path) -> Artifact:
    result = subprocess.run(build_mp3_command(source, destination), capture_output=True, shell=False, timeout=1800)
    if result.returncode:
        raise RuntimeError("CONVERSION_FAILED")
    return Artifact(destination, destination.name, "audio/mpeg", destination.stat().st_size)
