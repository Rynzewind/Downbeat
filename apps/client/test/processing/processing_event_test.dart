import 'package:downbeat/jobs/job.dart';
import 'package:downbeat/processing/processing_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProcessingEvent.progress', () {
    test('clamps percentages to the valid range', () {
      expect(
        const ProcessingEvent.progress(
          stage: JobState.downloading,
          percent: 140,
          bytesReceived: 12,
          totalBytes: 20,
        ).percent,
        100,
      );
      expect(
        const ProcessingEvent.progress(
          stage: JobState.downloading,
          percent: -4,
          bytesReceived: 0,
          totalBytes: 20,
        ).percent,
        0,
      );
    });

    test('keeps an unknown total indeterminate', () {
      const event = ProcessingEvent.progress(
        stage: JobState.downloading,
        percent: null,
        bytesReceived: 4096,
        totalBytes: null,
      );

      expect(event.percent, isNull);
      expect(event.totalBytes, isNull);
      expect(event.bytesReceived, 4096);
    });
  });
}
