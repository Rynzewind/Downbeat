import '../jobs/job.dart';
import '../jobs/job_repository.dart';

final class RemoteJobEvent {
  const RemoteJobEvent({required this.sequence, required this.state, required this.percent, this.filename, this.message});
  final int sequence;
  final JobState state;
  final double? percent;
  final String? filename;
  final String? message;
}

abstract interface class RemoteEventSource {
  Future<List<RemoteJobEvent>> fetchEvents(String jobId, {required int after});
}

final class JobSynchronizer {
  const JobSynchronizer(this.repository, this.remote);
  final JobRepository repository;
  final RemoteEventSource remote;

  Future<void> reconcile(Iterable<Job> jobs) async {
    for (final initial in jobs.where((job) => job.state.isActive)) {
      var job = initial;
      final events = List<RemoteJobEvent>.of(await remote.fetchEvents(job.id, after: job.remoteSequence));
      events.sort((a, b) => a.sequence.compareTo(b.sequence));
      for (final event in events.where((event) => event.sequence > job.remoteSequence)) {
        job = job.copyWith(
          state: event.state,
          percent: event.percent,
          filename: event.filename,
          message: event.message,
          remoteSequence: event.sequence,
        );
        await repository.upsert(job);
      }
    }
  }
}
