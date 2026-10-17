from pathlib import Path


def write_cookie_file(path: Path, cookies: str | None) -> Path | None:
    if not cookies:
        return None
    path.write_text(cookies, encoding="utf-8")
    path.chmod(0o600)
    return path
