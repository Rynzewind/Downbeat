import test from 'node:test';
import assert from 'node:assert/strict';
import { collectExpired } from '../src/cleanup/expiry.ts';

test('expires abandoned output, partials, secrets and stale active metadata only', () => {
  const now = 10_000;
  const result = collectExpired([
    { id: 'output', kind: 'output', expiresAt: 9_999 },
    { id: 'partial', kind: 'partial', expiresAt: 9_000 },
    { id: 'secret', kind: 'secret', expiresAt: 9_500 },
    { id: 'active', kind: 'active', expiresAt: 9_999 },
    { id: 'history', kind: 'local-history', expiresAt: 1 },
    { id: 'future', kind: 'output', expiresAt: 20_000 },
  ], now);
  assert.deepEqual(result.map(item => item.id), ['output', 'partial', 'secret', 'active']);
});
