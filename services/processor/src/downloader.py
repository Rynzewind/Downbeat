from pathlib import Path

from .ffmpeg import convert_audio_to_mp3
from .models import Artifact, JobFormat, ProcessorRequest
from .secrets import write_cookie_file
from .workspace import JobWorkspace
from .ytdlp_download import download_with_ytdlp


def process(request: ProcessorRequest, workspace: JobWorkspace, progress_sink=lambda event: None) -> Artifact:
    cookie_file = write_cookie_file(workspace.cookie_file, request.cookies)
    downloaded = download_with_ytdlp(request, workspace.root / "source.%(ext)s", cookie_file, progress_sink)
    if request.format is JobFormat.MP3:
        return convert_audio_to_mp3(downloaded.path, workspace.root / "download.mp3")
    return downloaded
