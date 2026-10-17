import { requireDevice, type DeviceAuthenticator } from './auth/device-auth.ts';
import { MemoryJobStore } from './jobs/job-object.ts';
import { routeJobs } from './jobs/job-routes.ts';

export interface ApiOptions { authenticate: DeviceAuthenticator; store?: MemoryJobStore }

export function createApi(options: ApiOptions): { fetch(request: Request): Promise<Response> } {
  const store = options.store ?? new MemoryJobStore();
  return { async fetch(request) {
    const deviceId = await requireDevice(request, options.authenticate);
    if (!deviceId) return Response.json({ error: { code: 'UNAUTHORIZED', message: 'Valid device credentials are required' } }, { status: 401 });
    return routeJobs(request, deviceId, store);
  } };
}

const workerStore = new MemoryJobStore();

export default { fetch(request: Request, env: { DEVICE_TOKEN?: string }) {
  const token = env.DEVICE_TOKEN;
  return createApi({ authenticate: value => token && value === token ? 'default-device' : null, store: workerStore }).fetch(request);
} };
