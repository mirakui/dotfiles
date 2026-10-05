export type Totals = {
  input: number
  output: number
  cacheRead: number
  cacheWrite: number
  turns: number
}

export type Meter = {
  contextTokens?: number
  contextWindow: number
  contextPercent?: number
  costUsd?: number
  rateLimits: { kind: string; percentUsed: number }[]
}

declare module 'claude-code' {
  interface PluginState {
    'token-usage': {
      totals: Totals
      meter: Meter
    }
  }
}
