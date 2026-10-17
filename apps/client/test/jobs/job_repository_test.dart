import 'package:episode_downloader/jobs/job.dart';
import 'package:episode_downloader/jobs/job_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reorders queued jobs and clearFinished preserves active work', () async {
    final repository = MemoryJobRepository();
    final first = Job(
      id: '1',
      sourceUrl: Uri.parse('https://example.com/1'),
      format: JobFormat.mp4,
      createdAt: DateTime.utc(2026),
    );
    final second = Job(
      id: '2',
      sourceUrl: Uri.parse('https://example.com/2'),
      format: JobFormat.mp3,
      createdAt: DateTime.utc(2026, 1, 2),
    );
    final complete = Job(
      id: '3',
      sourceUrl: Uri.parse('https://example.com/3'),
      format: JobFormat.mp4,
      state: JobState.completed,
      createdAt: DateTime.utc(2026, 1, 3),
    );
    await repository.upsert(first);
    await repository.upsert(second);
    await repository.upsert(complete);

    await repository.reorder(const ['2', '1']);
    await repository.clearFinished();

    expect(repository.current.map((job) => job.id), ['2', '1']);
  });

  test('refuses to remove active jobs', () async {
    final repository = MemoryJobRepository();
    await repository.upsert(
      Job(
        id: '1',
        sourceUrl: Uri.parse('https://example.com/1'),
        format: JobFormat.mp4,
        state: JobState.downloading,
        createdAt: DateTime.utc(2026),
      ),
    );

    expect(() => repository.remove('1'), throwsStateError);
  });
}
