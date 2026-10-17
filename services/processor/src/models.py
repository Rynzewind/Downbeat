from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path


class JobFormat(StrEnum):
    MP4 = "mp4"
    MP3 = "mp3"


@dataclass(frozen=True)
class ProcessorRequest:
    job_id: str
    source_url: str
    format: JobFormat
    callback_url: str
    callback_token: str
    cookies: str | None = None


@dataclass(frozen=True)
class Artifact:
    path: Path
    filename: str
    content_type: str
    size: int
