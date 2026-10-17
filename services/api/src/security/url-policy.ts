import { isIP } from 'node:net';

export class UnsafeUrlError extends Error {
  constructor(message = 'URL is not allowed') {
    super(message);
    this.name = 'UnsafeUrlError';
  }
}

function ipv4Number(address: string): number | null {
  const parts = address.split('.');
  if (parts.length !== 4 || parts.some(part => !/^\d+$/.test(part) || Number(part) > 255)) return null;
  return parts.reduce((value, part) => (value * 256 + Number(part)) >>> 0, 0);
}

export function isPublicAddress(rawAddress: string): boolean {
  const address = rawAddress.replace(/^\[|\]$/g, '').toLowerCase();
  const family = isIP(address);
  if (family === 4) {
    const value = ipv4Number(address)!;
    const first = value >>> 24;
    const second = (value >>> 16) & 255;
    if (first === 0 || first === 10 || first === 127 || first >= 224) return false;
    if (first === 100 && second >= 64 && second <= 127) return false;
    if (first === 169 && second === 254) return false;
    if (first === 172 && second >= 16 && second <= 31) return false;
    if (first === 192 && second === 168) return false;
    if (first === 192 && second === 0) return false;
    if (first === 198 && (second === 18 || second === 19)) return false;
    return true;
  }
  if (family === 6) {
    if (address === '::' || address === '::1') return false;
    if (/^f[cd]/.test(address) || /^fe[89ab]/.test(address) || /^ff/.test(address)) return false;
    if (address.startsWith('::ffff:')) return isPublicAddress(address.slice(7));
    return true;
  }
  return false;
}

export function assertSafeUrl(value: string): URL {
  let url: URL;
  try { url = new URL(value); } catch { throw new UnsafeUrlError('Malformed URL'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.port) throw new UnsafeUrlError();
  const hostname = url.hostname.replace(/^\[|\]$/g, '').toLowerCase();
  if (hostname === 'localhost' || hostname.endsWith('.localhost') || hostname.endsWith('.local')) throw new UnsafeUrlError();
  if (isIP(hostname) && !isPublicAddress(hostname)) throw new UnsafeUrlError();
  return url;
}

export function assertSafeResolution(addresses: readonly string[]): void {
  if (addresses.length === 0 || addresses.some(address => !isPublicAddress(address))) throw new UnsafeUrlError('Host resolved to a private address');
}
