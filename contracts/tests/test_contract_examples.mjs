import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const states = [
  'queued',
  'fetching',
  'downloading',
  'converting',
  'paused',
  'completed',
  'failed',
  'cancelled',
];

test('contract declares every supported job state and format', async () => {
  const contract = await readFile(new URL('../openapi.yaml', import.meta.url), 'utf8');

  for (const state of states) {
    assert.match(contract, new RegExp(`\\n\\s+- ${state}\\s*(?:\\n|$)`));
  }
  assert.match(contract, /enum: \[mp4, mp3\]/);
});

for (const fixture of ['job-created', 'job-progress', 'job-completed']) {
  test(`${fixture} example contains contract-required identity and state`, async () => {
    const value = JSON.parse(
      await readFile(new URL(`../examples/${fixture}.json`, import.meta.url), 'utf8'),
    );

    assert.equal(typeof value.jobId, 'string');
    assert.ok(value.jobId.length > 0);
    assert.ok(states.includes(value.state));
    assert.equal(typeof value.sequence, 'number');
  });
}
