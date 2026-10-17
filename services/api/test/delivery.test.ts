import test from 'node:test';
import assert from 'node:assert/strict';
import { DeliveryService, type ObjectStore } from '../src/delivery/r2-delivery.ts';
import { routeDelivery } from '../src/delivery/delivery-routes.ts';
import { createApi } from '../src/index.ts';

class FakeStore implements ObjectStore {
  objects = new Map<string, Uint8Array>();
  async delete(key: string) { this.objects.delete(key); }
  async has(key: string) { return this.objects.has(key); }
}

test('delivery token is device scoped and expires', async () => {
  const store = new FakeStore();
  store.objects.set('jobs/j/file', new Uint8Array([1, 2, 3]));
  const service = new DeliveryService(store, 'test-signing-secret');
  const issued = await service.issue({ jobId: 'j', deviceId: 'phone', objectKey: 'jobs/j/file', size: 3, sha256: 'abc' }, 1000, 60);
  assert.equal((await service.authorize(issued.token, 'phone', 1050)).objectKey, 'jobs/j/file');
  await assert.rejects(() => service.authorize(issued.token, 'desktop', 1050), /device/i);
  await assert.rejects(() => service.authorize(issued.token, 'phone', 1061), /expired/i);
});

test('only verified acknowledgement deletes output and duplicates are harmless', async () => {
  const store = new FakeStore();
  store.objects.set('jobs/j/file', new Uint8Array([1, 2, 3]));
  const service = new DeliveryService(store, 'test-signing-secret');
  const { token } = await service.issue({ jobId: 'j', deviceId: 'phone', objectKey: 'jobs/j/file', size: 3, sha256: 'abc' }, 1000, 60);
  await assert.rejects(() => service.acknowledge(token, 'phone', { size: 2, sha256: 'abc' }, 1010), /mismatch/i);
  assert.equal(await store.has('jobs/j/file'), true);
  assert.equal(await service.acknowledge(token, 'phone', { size: 3, sha256: 'abc' }, 1010), true);
  assert.equal(await store.has('jobs/j/file'), false);
  assert.equal(await service.acknowledge(token, 'phone', { size: 3, sha256: 'abc' }, 1010), false);
});

test('delivery route never exposes a permanent object URL', async () => {
  const store = new FakeStore();
  store.objects.set('jobs/j/file', new Uint8Array([1, 2, 3]));
  const service = new DeliveryService(store, 'test-signing-secret');
  const { token } = await service.issue({ jobId: 'j', deviceId: 'phone', objectKey: 'jobs/j/file', size: 3, sha256: 'abc' }, 1000, 60);
  const response = await routeDelivery(new Request('https://api.downbeat.test/v1/jobs/j/delivery', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ token, size: 3, sha256: 'abc' }),
  }), 'phone', service, 1010);
  assert.equal(response.status, 200);
  const body = await response.json() as any;
  assert.deepEqual(body, { acknowledged: true });
  assert.equal(JSON.stringify(body).includes('jobs/j/file'), false);
});

test('API entry point routes authenticated delivery acknowledgement', async () => {
  const store = new FakeStore();
  store.objects.set('jobs/j/file', new Uint8Array([1, 2, 3]));
  const deliveryService = new DeliveryService(store, 'test-signing-secret');
  const { token } = await deliveryService.issue({ jobId: 'j', deviceId: 'phone', objectKey: 'jobs/j/file', size: 3, sha256: 'abc' }, 1000, 60);
  const api = createApi({ authenticate: () => 'phone', deliveryService, now: () => 1010 });
  const response = await api.fetch(new Request('https://api.downbeat.test/v1/jobs/j/delivery', {
    method: 'POST', headers: { authorization: 'Bearer valid', 'content-type': 'application/json' }, body: JSON.stringify({ token, size: 3, sha256: 'abc' }),
  }));
  assert.equal(response.status, 200);
  assert.equal(await store.has('jobs/j/file'), false);
});
