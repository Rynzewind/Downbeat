import 'package:episode_downloader/jobs/job.dart';
import 'package:episode_downloader/jobs/job_transition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final queued = Job(
    id: 'local-1',
    sourceUrl: Uri.parse('https://example.com/watch/1'),
    format: JobFormat.mp4,
    title: 'Example episode',
    createdAt: DateTime.utc(2026, 10, 17),
  );

  test('applies legal progress transitions', () {
    final fetching = JobTransition.apply(
      queued,
      const JobEvent.stateChanged(JobState.fetching),
    );
    final downloading = JobTransition.apply(
      fetching,
      const JobEvent.progress(JobState.downloading, 42),
    );

    expect(fetching.state, JobState.fetching);
    expect(downloading.state, JobState.downloading);
    expect(downloading.percent, 42);
  });

  test('rejects transition out of a terminal state', () {
    final completed = queued.copyWith(state: JobState.completed, percent: 100);

    expect(
      () => JobTransition.apply(
        completed,
        const JobEvent.stateChanged(JobState.downloading),
      ),
      throwsStateError,
    );
  });

  test('redownload retains source and format with a fresh identity', () {
    final completed = queued.copyWith(
      state: JobState.completed,
      percent: 100,
      filename: 'Example episode.mp4',
    );

    final fresh = completed.redownload(
      id: 'local-2',
      createdAt: DateTime.utc(2026, 10, 18),
    );

    expect(fresh.id, 'local-2');
    expect(fresh.sourceUrl, completed.sourceUrl);
    expect(fresh.format, completed.format);
    expect(fresh.state, JobState.queued);
    expect(fresh.percent, isNull);
    expect(fresh.filename, isNull);
  });
}
