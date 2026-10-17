from pathlib import Path
from urllib.parse import urlsplit
import subprocess

from .models import Artifact, JobFormat, ProcessorRequest
from .progress import parse_progress_line


def _https_url(value: str) -> str:
    parsed = urlsplit(value)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("unsafe media URL")
    return value


def build_ytdlp_command(request: ProcessorRequest, output: Path, cookie_file: Path | None) -> list[str]:
    source_url = _https_url(request.source_url)
    selection = "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b" if request.format is JobFormat.MP4 else "bestaudio/best"
    command = ["yt-dlp", "--no-playlist", "--no-warnings", "--newline", "--progress-template", "download:%(progress._percent_str)s:%(progress.downloaded_bytes)s:%(progress.total_bytes)s", "-f", selection]
    if request.format is JobFormat.MP4:
        command += ["--merge-output-format", "mp4"]
    if cookie_file:
        command += ["--cookies", str(cookie_file)]
    command += ["-o", str(output), "--", source_url]
    return command


def download_with_ytdlp(request: ProcessorRequest, output: Path, cookie_file: Path | None, progress_sink=lambda event: None) -> Artifact:
    process = subprocess.Popen(build_ytdlp_command(request, output, cookie_file), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=False)
    stdout, _ = process.communicate()
    if process.returncode:
        raise RuntimeError("MEDIA_DOWNLOAD_FAILED")
    for line in stdout.splitlines():
        if event := parse_progress_line(line):
            progress_sink(event)
    matches = sorted(output.parent.glob(output.name.replace("%(ext)s", "*")))
    if not matches:
        raise RuntimeError("MEDIA_OUTPUT_MISSING")
    path = matches[0]
    return Artifact(path, path.name, "video/mp4" if request.format is JobFormat.MP4 else "application/octet-stream", path.stat().st_size)
