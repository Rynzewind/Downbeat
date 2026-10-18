import 'package:downbeat/jobs/job.dart';
import 'package:downbeat/jobs/job_repository.dart';
import 'package:downbeat/sync/job_synchronizer.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeRemoteEvents implements RemoteEventSource {
  int? requestedAfter;
  List<RemoteJobEvent> events = const [];
  @override Future<List<RemoteJobEvent>> fetchEvents(String jobId, {required int after}) async { requestedAfter = after; return events; }
}

void main() {
  test('restart resumes active job after persisted sequence and applies missed events', () async {
    final repository = MemoryJobRepository();
    final active = Job(id: 'remote-1', sourceUrl: Uri.parse('https://example.com/v'), format: JobFormat.mp4, createdAt: DateTime.utc(2026), state: JobState.downloading, percent: 20, remoteSequence: 1);
    await repository.upsert(active);
    final remote = FakeRemoteEvents()..events = const [
      RemoteJobEvent(sequence: 2, state: JobState.downloading, percent: 70),
      RemoteJobEvent(sequence: 3, state: JobState.completed, percent: 100, filename: 'video.mp4'),
    ];
    await JobSynchronizer(repository, remote).reconcile([active]);
    expect(remote.requestedAfter, 1);
    expect(repository.current.single.state, JobState.completed);
    expect(repository.current.single.remoteSequence, 3);
    expect(repository.current.single.filename, 'video.mp4');
  });

  test('terminal local jobs are not re-polled', () async {
    final repository = MemoryJobRepository();
    final remote = FakeRemoteEvents();
    final complete = Job(id: 'done', sourceUrl: Uri.parse('https://example.com/v'), format: JobFormat.mp3, createdAt: DateTime.utc(2026), state: JobState.completed);
    await JobSynchronizer(repository, remote).reconcile([complete]);
    expect(remote.requestedAfter, isNull);
  });
}
