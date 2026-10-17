from pathlib import Path

import pytest

from src.workspace import job_workspace


@pytest.mark.parametrize("fails", [False, True])
def test_workspace_removes_secrets_and_partial_files(tmp_path: Path, fails: bool):
    captured = None
    with pytest.raises(RuntimeError) if fails else _does_not_raise():
        with job_workspace(tmp_path, "job-1") as workspace:
            captured = workspace.root
            workspace.cookie_file.write_text("session=private-cookie", encoding="utf-8")
            (workspace.root / "partial.tmp").write_bytes(b"partial")
            if fails:
                raise RuntimeError("boom")
    assert captured is not None and not captured.exists()


class _does_not_raise:
    def __enter__(self): return None
    def __exit__(self, *_): return False
