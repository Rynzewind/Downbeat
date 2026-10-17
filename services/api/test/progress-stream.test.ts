import test from 'node:test';
import assert from 'node:assert/strict';
import { ProgressStream } from '../src/jobs/progress-stream.ts';
import { MemoryJobStore } from '../src/jobs/job-object.ts';

test('replays only events after the reconnect sequence', () => {
  const stream = new ProgressStream('job-1');
  stream.publish({ state: 'fetching', percent: null });
  stream.publish({ state: 'downloading', percent: 25 });
  stream.publish({ state: 'downloading', percent: 50 });
  assert.deepEqual(stream.after(1).map(event => event.sequence), [2, 3]);
});

test('supports indeterminate progress and rejects state regression', () => {
  const stream = new ProgressStream('job-1');
  assert.equal(stream.publish({ state: 'fetching', percent: null }).percent, null);
  stream.publish({ state: 'downloading', percent: 30 });
  assert.throws(() => stream.publish({ state: 'fetching', percent: null }), /regression/i);
});

test('emits a terminal event exactly once', () => {
  const stream = new ProgressStream('job-1');
  stream.publish({ state: 'completed', percent: 100 });
  assert.throws(() => stream.publish({ state: 'completed', percent: 100 }), /terminal/i);
  assert.equal(stream.after(0).filter(event => event.state === 'completed').length, 1);
});

test('job store persists authoritative progress and reconnect events', () => {
  const store = new MemoryJobStore();
  const { job } = store.create('phone', { clientRequestId: 'request', sourceUrl: 'https://example.com/v', format: 'mp4' });
  store.publish(job.jobId, { state: 'fetching', percent: null });
  store.publish(job.jobId, { state: 'downloading', percent: 55 });
  assert.equal(store.get('phone', job.jobId)?.state, 'downloading');
  assert.equal(store.get('phone', job.jobId)?.percent, 55);
  assert.deepEqual(store.eventsAfter('phone', job.jobId, 1).map(event => event.sequence), [2]);
  assert.deepEqual(store.eventsAfter('other-device', job.jobId, 0), []);
});
