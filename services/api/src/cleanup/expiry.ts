export type ExpirableKind = 'output' | 'partial' | 'secret' | 'active' | 'local-history';
export interface Expirable { id: string; kind: ExpirableKind; expiresAt: number }

export function collectExpired(items: readonly Expirable[], now: number): Expirable[] {
  return items.filter(item => item.kind !== 'local-history' && item.expiresAt <= now);
}

export async function deleteExpired(items: readonly Expirable[], now: number, remove: (item: Expirable) => Promise<void>): Promise<number> {
  const expired = collectExpired(items, now);
  await Promise.all(expired.map(remove));
  return expired.length;
}
