from pathlib import Path

from src.direct_download import safe_filename


def test_filename_is_safe_and_collision_resistant():
    assert safe_filename("../../CON?.mp4", set()) == "download.mp4"
    assert safe_filename("My Video.mp4", {"my video.mp4"}) == "My Video (2).mp4"
    assert safe_filename("name\x00.mp3", set()) == "name.mp3"
