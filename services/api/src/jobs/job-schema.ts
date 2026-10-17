import { assertSafeUrl, UnsafeUrlError } from '../security/url-policy.ts';

export type JobFormat = 'mp4' | 'mp3';
export interface JobCreate { clientRequestId: string; sourceUrl: string; format: JobFormat }

export function parseJobCreate(value: unknown): JobCreate {
  if (!value || typeof value !== 'object') throw new TypeError('Expected a JSON object');
  const input = value as Record<string, unknown>;
  if (typeof input.clientRequestId !== 'string' || input.clientRequestId.length < 1 || input.clientRequestId.length > 128) throw new TypeError('Invalid clientRequestId');
  if (input.format !== 'mp4' && input.format !== 'mp3') throw new TypeError('Invalid format');
  if (typeof input.sourceUrl !== 'string') throw new TypeError('Invalid sourceUrl');
  try { assertSafeUrl(input.sourceUrl); } catch (error) { if (error instanceof UnsafeUrlError) throw new TypeError('Unsafe sourceUrl'); throw error; }
  return { clientRequestId: input.clientRequestId, sourceUrl: input.sourceUrl, format: input.format };
}
