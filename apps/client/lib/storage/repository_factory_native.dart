import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../jobs/job_repository.dart';
import 'database.dart';

Future<JobRepository> openJobRepository() async {
  final support = await getApplicationSupportDirectory();
  return SqliteJobRepository.open(p.join(support.path, 'downbeat.sqlite'));
}
