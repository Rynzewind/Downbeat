export type ProgressState = 'queued' | 'fetching' | 'downloading' | 'converting' | 'paused' | 'completed' | 'failed' | 'cancelled';
export interface ProgressInput { state: ProgressState; percent: number | null }
export interface ProgressEvent extends ProgressInput { jobId: string; sequence: number }

const rank: Record<ProgressState, number> = {
  queued: 0, fetching: 1, downloading: 2, paused: 2, converting: 3,
  completed: 4, failed: 4, cancelled: 4,
};
const terminal = new Set<ProgressState>(['completed', 'failed', 'cancelled']);

export class ProgressStream {
  #events: ProgressEvent[] = [];
  readonly jobId: string;
  readonly limit: number;
  constructor(jobId: string, limit = 256) {
    this.jobId = jobId;
    this.limit = limit;
  }

  publish(input: ProgressInput): ProgressEvent {
    const previous = this.#events.at(-1);
    if (previous && terminal.has(previous.state)) throw new Error('Terminal event already emitted');
    if (previous && rank[input.state] < rank[previous.state]) throw new Error('State regression is not allowed');
    if (input.percent !== null && (input.percent < 0 || input.percent > 100)) throw new Error('Invalid progress percentage');
    const event = { ...input, jobId: this.jobId, sequence: (previous?.sequence ?? 0) + 1 };
    this.#events.push(event);
    if (this.#events.length > this.limit) this.#events.shift();
    return event;
  }

  after(sequence: number): ProgressEvent[] {
    return this.#events.filter(event => event.sequence > sequence).map(event => ({ ...event }));
  }
}
