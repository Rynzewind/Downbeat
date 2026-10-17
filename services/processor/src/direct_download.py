from pathlib import Path
import re
import urllib.request

from .models import Artifact

_RESERVED = {"CON", "PRN", "AUX", "NUL", *(f"COM{i}" for i in range(1, 10)), *(f"LPT{i}" for i in range(1, 10))}


def safe_filename(proposed: str, existing: set[str]) -> str:
    name = proposed.replace("\\", "/").split("/")[-1]
    name = re.sub(r"[\x00-\x1f<>:\"/\\|?*]", "", name).strip(" .")
    stem, suffix = Path(name).stem.strip(" ."), Path(name).suffix.lower()
    if not stem or stem.upper() in _RESERVED:
        stem = "download"
    candidate, number = f"{stem}{suffix}", 2
    lowered = {item.lower() for item in existing}
    while candidate.lower() in lowered:
        candidate = f"{stem} ({number}){suffix}"
        number += 1
    return candidate


def download_direct(url: str, destination: Path, progress_sink=lambda event: None, max_bytes: int = 2_147_483_648) -> Artifact:
    request = urllib.request.Request(url, headers={"User-Agent": "Downbeat/1"})
    with urllib.request.urlopen(request, timeout=30) as response, destination.open("wb") as output:
        total = int(response.headers.get("Content-Length", 0)) or None
        transferred = 0
        while chunk := response.read(256 * 1024):
            transferred += len(chunk)
            if transferred > max_bytes:
                raise RuntimeError("SIZE_LIMIT")
            output.write(chunk)
            progress_sink({"state": "downloading", "percent": transferred * 100 / total if total else None, "transferredBytes": transferred, "totalBytes": total})
    return Artifact(destination, destination.name, response.headers.get_content_type(), destination.stat().st_size)
