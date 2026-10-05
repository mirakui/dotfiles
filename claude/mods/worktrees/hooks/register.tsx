import type { EngineInterface, Register } from 'claude-code'

import type { Snapshot, Worktree } from '../types'

const PANE = 'worktrees'
const TITLE = 'Worktrees'
const REFRESH_MS = 30_000
const MAX_PATHS_PER_CALL = 10
const MAX_PARENT_HOPS = 4

const snapshot = { plugin: 'worktrees', key: 'snapshot' } as const
const referenced = { plugin: 'worktrees', key: 'referenced' } as const

let isRefreshing = false
let isRefreshPending = false
// Keyed by directory so a path inside a nested worktree (e.g. .claude/worktrees/*) is never
// attributed to the enclosing one.
const toplevelCache = new Map<string, string | null>()

function absolutePaths(text: string): string[] {
  return [...new Set(text.match(/\/[^\s"'`:;|&<>()\\]+/g) ?? [])]
}

function parentOf(path: string): string {
  return path.replace(/\/[^/]*\/?$/, '') || '/'
}

function basename(path: string): string {
  return path.replace(/\/+$/, '').split('/').pop() ?? path
}

function shorten(path: string, home: string | undefined): string {
  return home && path.startsWith(home) ? `~${path.slice(home.length)}` : path
}

async function toplevelOf($: EngineInterface, path: string): Promise<string | null> {
  let dir = path.replace(/\/+$/, '') || '/'
  for (let hop = 0; hop <= MAX_PARENT_HOPS && dir !== '/'; hop++) {
    const cached = toplevelCache.get(dir)
    if (cached !== undefined) return cached
    const res = await $.process
      .run(['git', '-C', dir, 'rev-parse', '--show-toplevel'], { timeoutMs: 5_000 })
      .catch(() => null)
    if (res && res.exitCode === 0) {
      const top = res.stdout.trim()
      toplevelCache.set(dir, top)
      return top
    }
    // "not a git repository" for an existing directory is final; a missing path falls back to its parent.
    if (res && /not a git repository/.test(res.stderr)) {
      toplevelCache.set(dir, null)
      return null
    }
    dir = parentOf(dir)
  }
  return null
}

async function describe($: EngineInterface, path: string, current: string | null): Promise<Worktree> {
  const head = await $.process
    .run(
      ['git', '-C', path, 'rev-parse', '--abbrev-ref', 'HEAD', '--path-format=absolute', '--git-common-dir'],
      { timeoutMs: 10_000 },
    )
    .catch(() => null)
  if (!head || head.exitCode !== 0) {
    return { path, repo: basename(parentOf(path)), branch: null, isCurrent: false, isMissing: true, dirtyCount: 0 }
  }
  const [ref = 'HEAD', commonDir = path] = head.stdout.trim().split('\n')
  const repo = basename(commonDir.endsWith('/.git') ? parentOf(commonDir) : commonDir).replace(/\.git$/, '')
  const st = await $.process
    .run(['git', '-C', path, 'status', '--porcelain'], { timeoutMs: 10_000 })
    .catch(() => null)
  const dirtyCount = st && st.exitCode === 0 ? st.stdout.split('\n').filter(l => l !== '').length : 0
  return {
    path,
    repo,
    branch: ref === 'HEAD' ? null : ref,
    isCurrent: path === current,
    isMissing: false,
    dirtyCount,
  }
}

async function collect($: EngineInterface): Promise<Snapshot> {
  const current = await toplevelOf($, await $.session.cwd())
  const { value: seen = [] } = await $.state.get(referenced)
  const roots = [...new Set([...(current ? [current] : []), ...seen])]
  const worktrees = await Promise.all(roots.map(root => describe($, root, current)))
  worktrees.sort((a, b) => a.repo.localeCompare(b.repo) || a.path.localeCompare(b.path))
  return {
    worktrees,
    error: roots.length === 0 ? 'No git worktree referenced yet' : null,
    updatedAt: Date.now(),
  }
}

async function refresh($: EngineInterface): Promise<void> {
  if (isRefreshing) {
    isRefreshPending = true
    return
  }
  isRefreshing = true
  try {
    do {
      isRefreshPending = false
      await $.state.set(snapshot, await collect($))
    } while (isRefreshPending)
  } catch (err) {
    await $.state.set(snapshot, { worktrees: [], error: String(err), updatedAt: Date.now() })
  } finally {
    isRefreshing = false
  }
}

async function track($: EngineInterface, input: unknown): Promise<void> {
  const paths = absolutePaths(JSON.stringify(input)).slice(0, MAX_PATHS_PER_CALL)
  const roots = (await Promise.all(paths.map(p => toplevelOf($, p)))).filter(
    (r): r is string => r !== null,
  )
  if (roots.length === 0) return
  const { value: seen = [] } = await $.state.get(referenced)
  const added = [...new Set(roots)].filter(r => !seen.includes(r))
  if (added.length === 0) return
  await $.state.set(referenced, [...seen, ...added])
  await refresh($)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'worktrees',
      description: 'Show the git worktrees this session references in a pane',
    })
    void $.ui.open({ id: PANE, title: TITLE })
    void refresh($)
    $.clock.every(REFRESH_MS, () => void refresh($))

    return next(e)
  })

  on('command.run', { command: 'worktrees' }, async $ => {
    await $.ui.open({ id: PANE, title: TITLE })
    await refresh($)

    return { text: 'Worktrees pane opened.' }
  })

  on('tool.call', async ($, e, next) => {
    void track($, e).catch(() => undefined)

    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    void refresh($)

    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const { value } = await $.state.get(snapshot)
    const home = await $.env.get('HOME')

    if (value === undefined) {
      return <Text dimColor>Loading…</Text>
    }

    const repos = [...new Set(value.worktrees.map(w => w.repo))]

    return (
      <Box flexDirection="column">
        {value.error !== null && <Text dimColor>{value.error}</Text>}
        {repos.map(repo => (
          <Box key={`repo:${repo}`} flexDirection="column" marginBottom={1}>
            <Text bold>{repo}</Text>
            {value.worktrees
              .filter(w => w.repo === repo)
              .map(w => (
                <Box key={w.path} flexDirection="column">
                  <Text
                    bold={w.isCurrent}
                    color={w.isCurrent ? 'green' : undefined}
                    dimColor={w.isMissing}
                    wrap="truncate-end"
                  >
                    {w.isCurrent ? '● ' : '  '}
                    {w.branch ?? '(detached)'}
                    {w.dirtyCount > 0 ? ` [${w.dirtyCount} changed]` : ''}
                    {w.isMissing ? ' (removed)' : ''}
                  </Text>
                  <Box flexDirection="row">
                    <Text>{'  '}</Text>
                    <Button
                      key={`copy:${w.path}`}
                      label={'\u{29C9}'}
                      plain
                      dimColor
                      onPress={async press => {
                        const copied = await $.ui.copy({ text: w.path, surface: press.surface })
                        $.ui.toast(
                          copied.isCopied ? `Copied ${w.path}` : `Copy failed: ${copied.reason}`,
                        )
                      }}
                    />
                    <Text dimColor wrap="truncate-start">
                      {' '}
                      {shorten(w.path, home)}
                    </Text>
                  </Box>
                </Box>
              ))}
          </Box>
        ))}
        <Text dimColor>
          {value.worktrees.length} worktrees in {repos.length} repos · updated{' '}
          {new Date(value.updatedAt).toLocaleTimeString()}
        </Text>
      </Box>
    )
  })
}
