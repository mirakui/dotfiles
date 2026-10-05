export type Worktree = {
  path: string
  repo: string
  branch: string | null
  isCurrent: boolean
  isMissing: boolean
  dirtyCount: number
}

export type Snapshot = {
  worktrees: Worktree[]
  error: string | null
  updatedAt: number
}

declare module 'claude-code' {
  interface PluginState {
    worktrees: { snapshot: Snapshot; referenced: string[] }
  }
}
