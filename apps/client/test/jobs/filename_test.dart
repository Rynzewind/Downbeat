import 'package:downbeat/jobs/filename.dart';
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

  test('limits long Unicode names while preserving the extension', () {
    final result = safeFilename(List.filled(200, '🎵').join(), '.mp3', const {});

    expect(result.endsWith('.mp3'), isTrue);
    expect(result.runes.length, lessThanOrEqualTo(184));
  });
}
