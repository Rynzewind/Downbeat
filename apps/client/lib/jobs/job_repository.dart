import 'dart:async';

import 'job.dart';

abstract interface class JobRepository {
  Stream<List<Job>> watchAll();
  Future<void> upsert(Job job);
  Future<void> reorder(List<String> ids);
  Future<void> remove(String id);
  Future<void> clearFinished();
}

final class MemoryJobRepository implements JobRepository {
  final List<Job> _jobs = [];
  final StreamController<List<Job>> _changes =
      StreamController<List<Job>>.broadcast();

  List<Job> get current => List.unmodifiable(_jobs);

  void _emit() => _changes.add(current);

  @override
  Stream<List<Job>> watchAll() async* {
    yield current;
    yield* _changes.stream;
  }

  @override
  Future<void> upsert(Job job) async {
    final index = _jobs.indexWhere((existing) => existing.id == job.id);
    if (index == -1) {
      _jobs.add(job);
    } else {
      _jobs[index] = job;
    }
    _emit();
  }

  @override
  Future<void> reorder(List<String> ids) async {
    final byId = {for (final job in _jobs) job.id: job};
    final requested = ids.map((id) => byId[id]).whereType<Job>();
    final unmentioned = _jobs.where((job) => !ids.contains(job.id));
    _jobs
      ..clear()
      ..addAll(requested)
      ..addAll(unmentioned);
    _emit();
  }

  @override
  Future<void> remove(String id) async {
    final job = _jobs.where((item) => item.id == id).firstOrNull;
    if (job != null && job.state.isActive) {
      throw StateError('Cancel an active job before removing it');
    }
    _jobs.removeWhere((item) => item.id == id);
    _emit();
  }

  @override
  Future<void> clearFinished() async {
    _jobs.removeWhere((job) => job.state.isTerminal);
    _emit();
  }
}
