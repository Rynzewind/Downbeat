import type { JobCreate } from './job-schema.ts';

export interface JobRecord extends JobCreate { jobId: string; deviceId: string; sequence: number; state: 'queued'; percent: null }

export class MemoryJobStore {
  #jobs = new Map<string, JobRecord>();
  #requests = new Map<string, string>();

  create(deviceId: string, input: JobCreate): { job: JobRecord; created: boolean } {
    const key = `${deviceId}\u0000${input.clientRequestId}`;
    const existing = this.#requests.get(key);
    if (existing) return { job: this.#jobs.get(existing)!, created: false };
    const jobId = `job_${crypto.randomUUID()}`;
    const job: JobRecord = { ...input, jobId, deviceId, sequence: 0, state: 'queued', percent: null };
    this.#jobs.set(jobId, job);
    this.#requests.set(key, jobId);
    return { job, created: true };
  }

  get(deviceId: string, jobId: string): JobRecord | null {
    const job = this.#jobs.get(jobId);
    return job?.deviceId === deviceId ? job : null;
  }
}
