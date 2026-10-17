from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
import re
import shutil
import tempfile


@dataclass(frozen=True)
class JobWorkspace:
    root: Path
    cookie_file: Path


@contextmanager
def job_workspace(parent: Path, job_id: str):
    parent.mkdir(parents=True, exist_ok=True)
    safe_id = re.sub(r"[^A-Za-z0-9_-]", "_", job_id)[:80] or "job"
    root = Path(tempfile.mkdtemp(prefix=f"{safe_id}-", dir=parent))
    workspace = JobWorkspace(root=root, cookie_file=root / "cookies.txt")
    try:
        yield workspace
    finally:
        shutil.rmtree(root, ignore_errors=True)
