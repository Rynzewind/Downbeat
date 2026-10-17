import type { JobCreate } from './job-schema.ts';
import { ProgressStream, type ProgressEvent, type ProgressInput, type ProgressState } from './progress-stream.ts';

export interface JobRecord extends JobCreate { jobId: string; deviceId: string; sequence: number; state: ProgressState; percent: number | null }

export class MemoryJobStore {
  #jobs = new Map<string, JobRecord>();
  #requests = new Map<string, string>();
  #streams = new Map<string, ProgressStream>();

  create(deviceId: string, input: JobCreate): { job: JobRecord; created: boolean } {
    const key = `${deviceId}\u0000${input.clientRequestId}`;
    const existing = this.#requests.get(key);
    if (existing) return { job: this.#jobs.get(existing)!, created: false };
    const jobId = `job_${crypto.randomUUID()}`;
    const job: JobRecord = { ...input, jobId, deviceId, sequence: 0, state: 'queued', percent: null };
    this.#jobs.set(jobId, job);
    this.#requests.set(key, jobId);
    this.#streams.set(jobId, new ProgressStream(jobId));
    return { job, created: true };
  }

  get(deviceId: string, jobId: string): JobRecord | null {
    const job = this.#jobs.get(jobId);
    return job?.deviceId === deviceId ? job : null;
  }

  publish(jobId: string, input: ProgressInput): ProgressEvent {
    const job = this.#jobs.get(jobId);
    const stream = this.#streams.get(jobId);
    if (!job || !stream) throw new Error('Job not found');
    const event = stream.publish(input);
    job.sequence = event.sequence;
    job.state = event.state;
    job.percent = event.percent;
    return event;
  }

  eventsAfter(deviceId: string, jobId: string, sequence: number): ProgressEvent[] {
    if (!this.get(deviceId, jobId)) return [];
    return this.#streams.get(jobId)?.after(sequence) ?? [];
  }
}
