import test from 'node:test';
import assert from 'node:assert/strict';
import { assertSafeUrl, isPublicAddress } from '../src/security/url-policy.ts';

test('accepts ordinary public HTTPS URLs', () => {
  assert.equal(assertSafeUrl('https://example.com/video').hostname, 'example.com');
});

test('rejects unsafe schemes, local names, encoded IPs, and metadata', () => {
  const blocked = [
    'http://example.com', 'file:///tmp/a', 'https://localhost/a', 'https://router.local/a',
    'https://127.0.0.1/a', 'https://2130706433/a', 'https://0x7f000001/a',
    'https://169.254.169.254/latest/meta-data', 'https://[::1]/a', 'https://10.0.0.1/a',
  ];
  for (const value of blocked) assert.throws(() => assertSafeUrl(value), { name: 'UnsafeUrlError' }, value);
});

test('rejects private, loopback, link-local, multicast and unspecified resolved addresses', () => {
  for (const address of ['0.0.0.0', '10.1.2.3', '172.16.0.1', '192.168.1.1', '127.1.2.3', '169.254.1.2', '::1', 'fc00::1', 'fe80::1']) {
    assert.equal(isPublicAddress(address), false, address);
  }
  assert.equal(isPublicAddress('93.184.216.34'), true);
  assert.equal(isPublicAddress('2606:2800:220:1:248:1893:25c8:1946'), true);
});
