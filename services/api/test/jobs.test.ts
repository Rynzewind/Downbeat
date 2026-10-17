import test from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../src/index.ts';

const token = 'device-secret';
const api = () => createApi({ authenticate: value => value === token ? 'phone-1' : null });
const request = (path: string, init: RequestInit = {}) => new Request(`https://api.downbeat.test${path}`, init);
const auth = { authorization: `Bearer ${token}`, 'content-type': 'application/json' };

test('rejects missing and invalid device credentials', async () => {
  assert.equal((await api().fetch(request('/v1/jobs'))).status, 401);
  assert.equal((await api().fetch(request('/v1/jobs', { headers: { authorization: 'Bearer wrong' } }))).status, 401);
});

test('creates jobs idempotently for one device', async () => {
  const service = api();
  const body = JSON.stringify({ clientRequestId: 'request-1', sourceUrl: 'https://example.com/watch/1', format: 'mp3' });
  const first = await service.fetch(request('/v1/jobs', { method: 'POST', headers: auth, body }));
  const second = await service.fetch(request('/v1/jobs', { method: 'POST', headers: auth, body }));
  assert.equal(first.status, 201);
  assert.equal(second.status, 200);
  assert.equal((await first.json() as any).jobId, (await second.json() as any).jobId);
});

test('returns 400 for invalid format and unsafe URL', async () => {
  const service = api();
  for (const body of [
    { clientRequestId: 'a', sourceUrl: 'https://example.com/v', format: 'wav' },
    { clientRequestId: 'b', sourceUrl: 'http://127.0.0.1/private', format: 'mp4' },
  ]) {
    const response = await service.fetch(request('/v1/jobs', { method: 'POST', headers: auth, body: JSON.stringify(body) }));
    assert.equal(response.status, 400);
  }
});

test('hides jobs belonging to another device', async () => {
  const service = createApi({ authenticate: value => value === 'one' ? 'device-1' : value === 'two' ? 'device-2' : null });
  const created = await service.fetch(request('/v1/jobs', {
    method: 'POST', headers: { authorization: 'Bearer one', 'content-type': 'application/json' },
    body: JSON.stringify({ clientRequestId: 'r', sourceUrl: 'https://example.com/v', format: 'mp4' }),
  }));
  const { jobId } = await created.json() as any;
  const response = await service.fetch(request(`/v1/jobs/${jobId}`, { headers: { authorization: 'Bearer two' } }));
  assert.equal(response.status, 404);
});
