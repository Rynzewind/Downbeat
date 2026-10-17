import { DeliveryService } from './r2-delivery.ts';

export async function routeDelivery(request: Request, deviceId: string, service: DeliveryService, now = Math.floor(Date.now() / 1000)): Promise<Response> {
  if (request.method !== 'POST') return Response.json({ error: { code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed' } }, { status: 405 });
  try {
    const body = await request.json() as Record<string, unknown>;
    if (typeof body.token !== 'string' || typeof body.size !== 'number' || typeof body.sha256 !== 'string') throw new Error('Invalid delivery acknowledgement');
    const acknowledged = await service.acknowledge(body.token, deviceId, { size: body.size, sha256: body.sha256 }, now);
    return Response.json({ acknowledged }, { headers: { 'cache-control': 'no-store' } });
  } catch (cause) {
    const message = cause instanceof Error ? cause.message : 'Invalid delivery acknowledgement';
    const status = /device|token|expired/i.test(message) ? 404 : 400;
    return Response.json({ error: { code: status === 404 ? 'DELIVERY_NOT_FOUND' : 'DELIVERY_INVALID', message } }, { status });
  }
}
