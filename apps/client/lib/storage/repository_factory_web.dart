import '../jobs/job_repository.dart';

Future<JobRepository> openJobRepository() async => MemoryJobRepository();
