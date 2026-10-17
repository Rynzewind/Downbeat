from src.progress import parse_progress_line


def test_parses_machine_progress_without_echoing_source_text():
    event = parse_progress_line("download:42.5:8912896:20971520")
    assert event == {"state": "downloading", "percent": 42.5, "transferredBytes": 8912896, "totalBytes": 20971520}


def test_ignores_unstructured_output():
    assert parse_progress_line("cookie=session-secret") is None


def test_accepts_ytdlp_percent_formatting():
    assert parse_progress_line("download: 42.5%:10:20")["percent"] == 42.5
