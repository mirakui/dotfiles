---
name: resolve-conflicts
description: >-
  Investigate and resolve merge conflicts on GitHub pull requests. For each target PR, spawns a
  Sonnet sub-agent that merges the base branch into the PR head inside a temporary git worktree,
  resolves conflicts by understanding both sides, runs the project's checks, then commits and pushes
  (no force push). Takes PR numbers / URLs as arguments (defaults to the current branch's PR).
  Trigger on "resolve conflicts", "conflict 解消", "コンフリクト解消", "コンフリクト直して",
  "PR のコンフリクト", "merge conflict", "fix conflicts", "conflicting PR".
user-invocable: true
argument-hint: "[PR number | PR URL ...]"
---

# Resolve Conflicts

Resolve merge conflicts on one or more GitHub PRs. **The parent (you) only orchestrates**; each PR's
actual conflict resolution runs in its own sub-agent on **Sonnet**.

Policy (fixed — do not ask the user again):

- Bring the base in with **`git merge origin/<base>`** — never rebase, never force push.
- Work in a **temporary git worktree** so the user's checkout is never touched.
- **Push automatically** once checks pass. If a conflict needs a human decision, do not push —
  report it instead.

## 1. Resolve target PRs

- Arguments may be PR numbers or PR URLs, one or many.
- No argument → the PR for the current branch (`gh pr view --json number`). If there is none, tell
  the user and stop.
- For a URL whose `owner/repo` differs from the current repo's remote, find a local clone (e.g.
  `repos/<repo>` under the cwd). If none is found, report that PR as skipped — do not clone.

## 2. Preflight each PR (parent does this, cheap)

```bash
gh pr view <PR> --repo <owner>/<repo> --json number,url,title,state,mergeable,mergeStateStatus,baseRefName,headRefName,isCrossRepository,maintainerCanModify,headRepositoryOwner,headRepository
```

- `mergeable` is often `UNKNOWN` right after a push while GitHub computes it. Re-query up to 3 times
  with a short wait (use a background `sleep 10`, since foreground sleep is blocked).
- Skip, with a reason, when:
  - `state` is not `OPEN`
  - `mergeable` is `MERGEABLE` (no conflict — nothing to do)
  - `isCrossRepository` is true and `maintainerCanModify` is false (cannot push to the fork)
- Only `mergeable == CONFLICTING` goes on to step 3.

## 3. Spawn one Sonnet sub-agent per conflicting PR

Read [agent-prompt.md](agent-prompt.md), fill in the placeholders, and launch it with the Agent tool:

- `subagent_type: "general-purpose"`
- `model: "sonnet"` — **required**; this is the point of the skill
- `description: "Resolve conflicts PR #<N>"`

With multiple PRs, launch all agents **in a single message** so they run in parallel. Each works in
its own worktree, so they do not interfere. If two PRs share the same head branch, run them serially.

Wait for every agent to finish (they notify on completion — do not poll).

## 4. Verify and report

For each PR an agent reports as `resolved`, re-query `gh pr view --json mergeable,mergeStateStatus`
and confirm it is no longer `CONFLICTING` (allow for `UNKNOWN` as in step 2).

Then give the user one table:

| PR | Result | Conflicting files | How resolved | Checks | Commit |
|----|--------|-------------------|--------------|--------|--------|

- `resolved`: link the pushed commit.
- `needs-human`: list the exact files/hunks and the decision needed, plus the worktree path the agent
  left behind so the user can pick it up.
- `skipped`: the reason from step 1/2.

If a local branch with the same name exists in the user's checkout, note that it is now behind the
remote (`git pull` needed) — do not update it yourself.

## Notes

- Stacked PRs (base is another PR branch): merging the base branch is still correct. If the repo is
  managed with `gh stack`, mention that `gh stack sync` / rebase is the stack-native alternative, but
  follow this skill's merge policy unless the user says otherwise.
- The sub-agent never edits files outside the conflict resolution itself, except fixes strictly
  required to make the merged result build/pass.
