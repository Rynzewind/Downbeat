enum JobFormat { mp4, mp3 }

enum JobState {
  queued,
  fetching,
  downloading,
  converting,
  paused,
  completed,
  failed,
  cancelled;

  bool get isTerminal =>
      this == completed || this == failed || this == cancelled;

  bool get isActive => !isTerminal;
}

const _unset = Object();

final class Job {
  const Job({
    required this.id,
    required this.sourceUrl,
    required this.format,
    required this.createdAt,
    this.title,
    this.filename,
    this.state = JobState.queued,
    this.percent,
    this.message,
  });

  final String id;
  final Uri sourceUrl;
  final JobFormat format;
  final DateTime createdAt;
  final String? title;
  final String? filename;
  final JobState state;
  final double? percent;
  final String? message;

  Job copyWith({
    String? id,
    Uri? sourceUrl,
    JobFormat? format,
    DateTime? createdAt,
    Object? title = _unset,
    Object? filename = _unset,
    JobState? state,
    Object? percent = _unset,
    Object? message = _unset,
  }) =>
      Job(
        id: id ?? this.id,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        format: format ?? this.format,
        createdAt: createdAt ?? this.createdAt,
        title: identical(title, _unset) ? this.title : title as String?,
        filename:
            identical(filename, _unset) ? this.filename : filename as String?,
        state: state ?? this.state,
        percent: identical(percent, _unset)
            ? this.percent
            : (percent as num?)?.toDouble(),
        message: identical(message, _unset) ? this.message : message as String?,
      );

  Job redownload({required String id, required DateTime createdAt}) => Job(
        id: id,
        sourceUrl: sourceUrl,
        format: format,
        createdAt: createdAt,
        title: title,
      );
}
