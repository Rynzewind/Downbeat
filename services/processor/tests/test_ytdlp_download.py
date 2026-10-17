from pathlib import Path

from src.models import JobFormat, ProcessorRequest
from src.ytdlp_download import build_ytdlp_command
from src.ffmpeg import build_mp3_command


def request(fmt=JobFormat.MP4):
    return ProcessorRequest(job_id="job-1", source_url="https://example.com/watch?v=1", format=fmt, callback_url="https://api.example/callback", callback_token="secret")


def test_mp4_uses_compatible_video_audio_and_no_shell():
    command = build_ytdlp_command(request(), Path("/work/out.%(ext)s"), None)
    assert command[0] == "yt-dlp"
    assert "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b" in command
    assert "--merge-output-format" in command
    assert all(";" not in arg for arg in command)


def test_mp3_uses_audio_and_ephemeral_cookie_file():
    cookie_file = Path("/work/private.cookies")
    command = build_ytdlp_command(request(JobFormat.MP3), Path("/work/out.%(ext)s"), cookie_file)
    assert "bestaudio/best" in command
    assert command[command.index("--cookies") + 1] == str(cookie_file)


def test_user_url_cannot_become_an_option():
    malicious = ProcessorRequest(job_id="j", source_url="--exec=bad", format=JobFormat.MP4, callback_url="https://api.example/c", callback_token="s")
    try:
        build_ytdlp_command(malicious, Path("/work/out"), None)
    except ValueError:
        pass
    else:
        raise AssertionError("unsafe URL accepted")


def test_ffmpeg_arguments_are_an_argv_list():
    command = build_mp3_command(Path("/work/source.webm"), Path("/work/result.mp3"))
    assert command[:3] == ["ffmpeg", "-nostdin", "-y"]
    assert command[-1] == "/work/result.mp3"
