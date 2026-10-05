import type { Register } from 'claude-code'

import type { Meter } from '../types'

const TOTALS = { plugin: 'token-usage', key: 'totals' } as const
const METER = { plugin: 'token-usage', key: 'meter' } as const
const ZERO = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, turns: 0 }
const LIMIT_LABEL: Record<string, string> = { five_hour: '5h', seven_day: '7d', spend_limit: 'spend' }

const fmt = (n: number) =>
  n >= 1_000_000 ? `${(n / 1_000_000).toFixed(2)}M` : n >= 1000 ? `${(n / 1000).toFixed(1)}k` : `${n}`

const level = (percent: number) => (percent >= 85 ? 'red' : percent >= 60 ? 'yellow' : 'green')

const toMeter = (u: {
  context: { tokens?: number; window: number; percent?: number }
  rateLimits: { kind: string; percentUsed: number }[]
  cost?: { usd: number }
}): Meter => ({
  contextTokens: u.context.tokens,
  contextWindow: u.context.window,
  contextPercent: u.context.percent,
  costUsd: u.cost?.usd,
  rateLimits: u.rateLimits.map(({ kind, percentUsed }) => ({ kind, percentUsed })),
})

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.state.set(METER, toMeter(await $.session.usage()))

    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const u = e.usage
    if (u) {
      const { value: t = ZERO } = await $.state.get(TOTALS)
      await $.state.set(TOTALS, {
        input: t.input + u.input_tokens + u.cache_read_input_tokens + u.cache_creation_input_tokens,
        output: t.output + u.output_tokens,
        cacheRead: t.cacheRead + u.cache_read_input_tokens,
        cacheWrite: t.cacheWrite + u.cache_creation_input_tokens,
        turns: t.turns + 1,
      })
    }
    await $.state.set(METER, toMeter(await $.session.usage()))

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const { value: m } = await $.state.get(METER)
    if (e.props.hasSurvey || !m) {
      return next(e)
    }

    const { value: t = ZERO } = await $.state.get(TOTALS)
    const { Box, Text } = $.ui.resolve(e)
    const percent = m.contextPercent ?? 0
    const width = e.props.bodyColumns >= 100 ? 12 : 6
    const filled = Math.round((Math.min(percent, 100) / 100) * width)
    const sep = <Text dimColor> · </Text>

    return (
      <Box>
        <Text wrap="truncate-end">
          <Text dimColor>Context </Text>
          <Text color={level(percent)}>{'█'.repeat(filled)}</Text>
          <Text dimColor>{'░'.repeat(width - filled)} </Text>
          <Text color={level(percent)} bold>
            {percent}%
          </Text>
          <Text dimColor>
            {' '}
            ({fmt(m.contextTokens ?? 0)}/{fmt(m.contextWindow)})
          </Text>
          {sep}
          <Text dimColor>in </Text>
          <Text color="cyan">{fmt(t.input)}</Text>
          <Text dimColor> out </Text>
          <Text color="magenta">{fmt(t.output)}</Text>
          {t.input > 0 && (
            <>
              {sep}
              <Text dimColor>cache </Text>
              <Text color="blue">{Math.round((t.cacheRead / t.input) * 100)}%</Text>
            </>
          )}
          {m.costUsd !== undefined && (
            <>
              {sep}
              <Text color="green" bold>
                ${m.costUsd.toFixed(2)}
              </Text>
            </>
          )}
          {m.rateLimits.map(r => (
            <>
              {sep}
              <Text dimColor>{LIMIT_LABEL[r.kind] ?? r.kind} </Text>
              <Text color={level(r.percentUsed)}>{r.percentUsed}%</Text>
            </>
          ))}
        </Text>
      </Box>
    )
  })
}
