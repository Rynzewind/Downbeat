import test from 'node:test';
import assert from 'node:assert/strict';
import { ProgressStream } from '../src/jobs/progress-stream.ts';
import { DeliveryService, type ObjectStore } from '../src/delivery/r2-delivery.ts';

test('processor progress leads to temporary delivery and verified cleanup', async () => {
  const objects = new Map<string, Uint8Array>();
  const store: ObjectStore = { delete: async key => { objects.delete(key); }, has: async key => objects.has(key) };
  const progress = new ProgressStream('job-1');
  progress.publish({ state: 'fetching', percent: null });
  progress.publish({ state: 'downloading', percent: 60 });
  objects.set('jobs/job-1/media.mp3', new Uint8Array([1, 2, 3]));
  progress.publish({ state: 'completed', percent: 100 });
  const delivery = new DeliveryService(store, 'integration-secret');
  const { token } = await delivery.issue({ jobId: 'job-1', deviceId: 'phone', objectKey: 'jobs/job-1/media.mp3', size: 3, sha256: 'hash' }, 100, 30);
  assert.equal(progress.after(1).length, 2);
  assert.equal(await delivery.acknowledge(token, 'phone', { size: 3, sha256: 'hash' }, 110), true);
  assert.equal(objects.size, 0);
});
