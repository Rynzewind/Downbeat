const secretKey = /authorization|cookie|password|secret|token|credential|signature|api[-_]?key/i;
const signedQuery = /token|signature|credential|key|expires/i;

function redactUrl(value: string): string {
  try {
    const url = new URL(value);
    for (const key of [...url.searchParams.keys()]) if (signedQuery.test(key)) url.searchParams.set(key, '[REDACTED]');
    return url.toString();
  } catch { return value; }
}

export function redact(value: unknown, key = ''): unknown {
  if (secretKey.test(key)) return '[REDACTED]';
  if (typeof value === 'string') return key.toLowerCase().includes('url') ? redactUrl(value) : value;
  if (Array.isArray(value)) return value.map(item => redact(item));
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([childKey, child]) => [childKey, redact(child, childKey)]));
  }
  return value;
}
