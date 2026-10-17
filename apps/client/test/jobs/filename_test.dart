import 'package:episode_downloader/jobs/filename.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizes traversal controls and Windows reserved names', () {
    expect(safeFilename('../CON\u0000', '.mp4', const {}), 'CON file.mp4');
  });

  test('adds a collision suffix without changing the extension', () {
    expect(
      safeFilename('Episode', '.mp3', const {'Episode.mp3'}),
      'Episode (2).mp3',
    );
  });
}
