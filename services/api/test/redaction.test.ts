import test from 'node:test';
import assert from 'node:assert/strict';
import { redact } from '../src/logging/redaction.ts';

test('redacts secrets, cookie headers, credentials, and signed URL query values recursively', () => {
  const value = redact({
    authorization: 'Bearer secret-token',
    headers: { Cookie: 'session=private-cookie' },
    url: 'https://cdn.example/file?token=signed-secret&X-Amz-Signature=abc&safe=yes',
    nested: [{ password: 'hunter2', message: 'ordinary failure' }],
  });
  const serialized = JSON.stringify(value);
  for (const secret of ['secret-token', 'private-cookie', 'signed-secret', 'abc', 'hunter2']) assert.equal(serialized.includes(secret), false);
  assert.equal(serialized.includes('ordinary failure'), true);
});
