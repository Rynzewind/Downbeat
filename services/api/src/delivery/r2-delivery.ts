export interface ObjectStore {
  delete(key: string): Promise<void>;
  has(key: string): Promise<boolean>;
}

export interface DeliveryClaims {
  jobId: string;
  deviceId: string;
  objectKey: string;
  size: number;
  sha256: string;
}

interface SignedClaims extends DeliveryClaims { expiresAt: number }

const encoder = new TextEncoder();
const encode = (bytes: Uint8Array) => Buffer.from(bytes).toString('base64url');
const decode = (value: string) => new Uint8Array(Buffer.from(value, 'base64url'));

export class DeliveryService {
  #acknowledged = new Set<string>();
  private readonly store: ObjectStore;
  private readonly secret: string;
  constructor(store: ObjectStore, secret: string) {
    if (secret.length < 12) throw new Error('Signing secret is too short');
    this.store = store;
    this.secret = secret;
  }

  async #signature(payload: string): Promise<Uint8Array> {
    const key = await crypto.subtle.importKey('raw', encoder.encode(this.secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    return new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(payload)));
  }

  async issue(claims: DeliveryClaims, now: number, ttlSeconds: number): Promise<{ token: string; expiresAt: number }> {
    const signed: SignedClaims = { ...claims, expiresAt: now + ttlSeconds };
    const payload = encode(encoder.encode(JSON.stringify(signed)));
    return { token: `${payload}.${encode(await this.#signature(payload))}`, expiresAt: signed.expiresAt };
  }

  async authorize(token: string, deviceId: string, now: number): Promise<SignedClaims> {
    const [payload, encodedSignature, extra] = token.split('.');
    if (!payload || !encodedSignature || extra) throw new Error('Invalid delivery token');
    const expected = await this.#signature(payload);
    const actual = decode(encodedSignature);
    let mismatch = expected.length ^ actual.length;
    for (let index = 0; index < Math.max(expected.length, actual.length); index++) mismatch |= (expected[index] ?? 0) ^ (actual[index] ?? 0);
    if (mismatch) throw new Error('Invalid delivery token');
    let claims: SignedClaims;
    try { claims = JSON.parse(new TextDecoder().decode(decode(payload))); } catch { throw new Error('Invalid delivery token'); }
    if (claims.deviceId !== deviceId) throw new Error('Delivery token belongs to another device');
    if (now > claims.expiresAt) throw new Error('Delivery token expired');
    return claims;
  }

  async acknowledge(token: string, deviceId: string, received: { size: number; sha256: string }, now: number): Promise<boolean> {
    const claims = await this.authorize(token, deviceId, now);
    const key = `${claims.deviceId}\u0000${claims.jobId}\u0000${claims.objectKey}`;
    if (this.#acknowledged.has(key)) return false;
    if (claims.size !== received.size || claims.sha256 !== received.sha256) throw new Error('Delivery acknowledgement mismatch');
    await this.store.delete(claims.objectKey);
    this.#acknowledged.add(key);
    return true;
  }
}
