import type { JobFormat } from './job-schema.ts';
import type { ProgressInput } from './progress-stream.ts';

export interface ProcessorRequest {
  jobId: string;
  sourceUrl: string;
  format: JobFormat;
  callbackUrl: string;
  callbackToken: string;
  cookies?: string;
}
export interface ProcessorClient {
  start(request: ProcessorRequest, onProgress: (event: ProgressInput) => void): Promise<void>;
  command(jobId: string, command: 'cancel' | 'pause' | 'resume'): Promise<void>;
}
