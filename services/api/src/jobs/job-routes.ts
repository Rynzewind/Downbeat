import { parseJobCreate } from './job-schema.ts';
import { MemoryJobStore } from './job-object.ts';

const json = (body: unknown, status = 200) => Response.json(body, { status, headers: { 'cache-control': 'no-store' } });
const error = (status: number, code: string, message: string) => json({ error: { code, message } }, status);

export async function routeJobs(request: Request, deviceId: string, store: MemoryJobStore): Promise<Response> {
  const url = new URL(request.url);
  if (request.method === 'POST' && url.pathname === '/v1/jobs') {
    try {
      const input = parseJobCreate(await request.json());
      const result = store.create(deviceId, input);
      const { deviceId: _private, clientRequestId: _idempotency, ...publicJob } = result.job;
      return json(publicJob, result.created ? 201 : 200);
    } catch (cause) {
      return error(400, 'INVALID_REQUEST', cause instanceof Error ? cause.message : 'Invalid request');
    }
  }
  const match = url.pathname.match(/^\/v1\/jobs\/([^/]+)$/);
  if (request.method === 'GET' && match) {
    const job = store.get(deviceId, decodeURIComponent(match[1]));
    if (!job) return error(404, 'JOB_NOT_FOUND', 'Job not found');
    const { deviceId: _private, clientRequestId: _idempotency, ...publicJob } = job;
    return json(publicJob);
  }
  return error(404, 'NOT_FOUND', 'Route not found');
}
