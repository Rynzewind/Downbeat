import { requireDevice, type DeviceAuthenticator } from './auth/device-auth.ts';
import { MemoryJobStore } from './jobs/job-object.ts';
import { routeJobs } from './jobs/job-routes.ts';
import { routeDelivery } from './delivery/delivery-routes.ts';
import type { DeliveryService } from './delivery/r2-delivery.ts';

export interface ApiOptions { authenticate: DeviceAuthenticator; store?: MemoryJobStore; deliveryService?: DeliveryService; now?: () => number }

export function createApi(options: ApiOptions): { fetch(request: Request): Promise<Response> } {
  const store = options.store ?? new MemoryJobStore();
  return { async fetch(request) {
    const deviceId = await requireDevice(request, options.authenticate);
    if (!deviceId) return Response.json({ error: { code: 'UNAUTHORIZED', message: 'Valid device credentials are required' } }, { status: 401 });
    const url = new URL(request.url);
    if (options.deliveryService && /^\/v1\/jobs\/[^/]+\/delivery$/.test(url.pathname)) {
      return routeDelivery(request, deviceId, options.deliveryService, options.now?.() ?? Math.floor(Date.now() / 1000));
    }
    return routeJobs(request, deviceId, store);
  } };
}

const workerStore = new MemoryJobStore();

export default { fetch(request: Request, env: { DEVICE_TOKEN?: string }) {
  const token = env.DEVICE_TOKEN;
  return createApi({ authenticate: value => token && value === token ? 'default-device' : null, store: workerStore }).fetch(request);
} };
