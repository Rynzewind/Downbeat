import 'job.dart';

sealed class JobEvent {
  const JobEvent();

  const factory JobEvent.stateChanged(JobState state) = JobStateChanged;
  const factory JobEvent.progress(JobState state, double? percent) =
      JobProgressed;
}

final class JobStateChanged extends JobEvent {
  const JobStateChanged(this.state);
  final JobState state;
}

final class JobProgressed extends JobEvent {
  const JobProgressed(this.state, this.percent);
  final JobState state;
  final double? percent;
}

abstract final class JobTransition {
  static Job apply(Job job, JobEvent event) {
    if (job.state.isTerminal) {
      throw StateError('A terminal job cannot transition');
    }
    return switch (event) {
      JobStateChanged(:final state) => job.copyWith(
        state: state,
        percent: state == JobState.completed ? 100.0 : job.percent,
      ),
      JobProgressed(:final state, :final percent) => job.copyWith(
        state: state,
        percent: percent?.clamp(0, 100).toDouble(),
      ),
    };
  }
}
