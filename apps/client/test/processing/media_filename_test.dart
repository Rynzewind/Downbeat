import 'package:downbeat/jobs/job.dart';
import 'package:downbeat/processing/media_filename.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses artist and title for audio filenames', () {
    expect(
      MediaFilename.customStem(
        JobFormat.mp3,
        title: 'A Song: Live?',
        artist: 'An/Artist',
      ),
      'An Artist - A Song Live',
    );
  });

  test('uses only the title for video filenames', () {
    expect(
      MediaFilename.customStem(
        JobFormat.mp4,
        title: 'My Video',
        artist: 'Ignored Artist',
      ),
      'My Video',
    );
  });

  test('keeps the source filename when title is blank', () {
    expect(
      MediaFilename.customStem(JobFormat.mp3, title: '   ', artist: 'Artist'),
      isNull,
    );
  });
}
