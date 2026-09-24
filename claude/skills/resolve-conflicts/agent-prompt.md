# Sub-agent prompt template

The parent fills the `{...}` placeholders from the step 2 preflight and passes the text below (from
"You are resolving") as the Agent `prompt`.

| Placeholder | Value |
|---|---|
| `{REPO_ROOT}` | Absolute path of the local clone (`git rev-parse --show-toplevel`) |
| `{OWNER_REPO}` | `owner/repo` of the PR |
| `{PR}` / `{PR_URL}` / `{PR_TITLE}` | From `gh pr view` |
| `{BASE}` / `{HEAD}` | `baseRefName` / `headRefName` |
| `{CROSS_REPO}` | `true` / `false` (`isCrossRepository`) |
| `{HEAD_REPO}` | `headRepositoryOwner.login/headRepository.name` (only meaningful when cross-repo) |

---

You are resolving merge conflicts on GitHub PR #{PR} ({PR_URL}) — "{PR_TITLE}" — in `{OWNER_REPO}`.
Base branch: `{BASE}`. Head branch: `{HEAD}`. Cross-repo (fork) PR: {CROSS_REPO} (head repo: `{HEAD_REPO}`).
Local clone: `{REPO_ROOT}`.

## Hard rules

- Integrate the base with `git merge`. **Never rebase, never force push, never `git push --force*`.**
- Work only inside the worktree created below. Never touch `{REPO_ROOT}`'s own working tree or branches.
- Never stage with `git add -A` / `git add .` — add resolved files by path.
- Do not delete files with `rm`; use `trash`. Use `pnpm` (not npm) and `uv` (not pip).
- If you cannot confidently resolve a conflict, **stop before committing** and report `needs-human`.
  A wrong silent resolution is far worse than asking.

## 1. Create the worktree

```bash
cd {REPO_ROOT}
git remote -v   # pick the remote whose URL is {OWNER_REPO}; call it $REMOTE (usually origin)
WT={REPO_ROOT}/.claude/worktrees/resolve-conflicts-pr-{PR}
git fetch $REMOTE {BASE}
```

- Same-repo PR: `git fetch $REMOTE {HEAD}` then `git worktree add --detach "$WT" $REMOTE/{HEAD}`
- Fork PR: `git fetch $REMOTE pull/{PR}/head` then `git worktree add --detach "$WT" FETCH_HEAD`

Use a detached HEAD so it does not collide with a local `{HEAD}` branch checked out elsewhere. If
`$WT` already exists from a previous run, inspect it; remove it with `git worktree remove` only if it
has no work worth keeping, otherwise report `needs-human`.

All following commands run in `$WT`.

## 2. Merge and investigate

```bash
git merge --no-commit --no-ff $REMOTE/{BASE}
git diff --name-only --diff-filter=U
```

If the merge is clean (no conflicted files), GitHub's state was stale: abort (`git merge --abort`),
clean up the worktree, and report `skipped` with "no conflict locally".

For each conflicted file, understand **why** both sides changed it before editing:

- `git log --oneline $REMOTE/{BASE} ^HEAD -- <file>` and `git log --oneline HEAD ^$REMOTE/{BASE} -- <file>`
- `git show <sha>` on the relevant commits to learn the intent of each change
- `git show :1:<file>` (ancestor), `:2:` (PR / ours), `:3:` (base / theirs) when the markers are hard to read
- `gh pr view {PR} --repo {OWNER_REPO}` for the PR's own intent

## 3. Resolve

- Default goal: keep **both** intents — the PR's change applied on top of what the base now looks like.
- Lockfiles (`pnpm-lock.yaml`, `uv.lock`, `Cargo.lock`, `go.sum`, …): do not hand-merge. Take the
  base version (`git checkout --theirs <file>`), then regenerate with the package manager
  (`pnpm install --lockfile-only`, `uv lock`, …) so it reflects the merged manifest.
- Generated files (codegen output, snapshots, schema dumps): regenerate with the project's generator
  instead of hand-merging, when a generator exists.
- Deleted-vs-modified: find out whether the base moved/renamed the file (`git log --follow --diff-filter=RD`)
  and port the PR's change to the new location; otherwise → `needs-human`.
- **`needs-human`** when resolution requires a product/design decision: both sides changed the same
  logic with incompatible intent, a migration ordering/numbering clash, or you cannot tell which
  behavior is intended.
- Config files that tooling depends on (e.g. `mise.toml`): while they contain markers, tools shimmed
  by them break (`command not found`). Resolve them first, and use absolute system binaries
  (`/usr/bin/python3`) if you need a script in the meantime.

After resolving, confirm no markers remain:

```bash
git diff --check
git diff --name-only HEAD | xargs grep -s -nE '^(<<<<<<<|=======|>>>>>>>)( |$)' || true
```

Also check for semantic breakage the merge did not flag: code in the PR that calls something the
base renamed/removed, duplicated imports, etc.

## 4. Verify

Discover the project's checks (README / CLAUDE.md / `package.json` scripts / `mise tasks` / Makefile /
CI workflow files) and run format, lint, type-check/build, and tests. Install dependencies first if the
fresh worktree needs them. Fix failures that the merge caused. If failures also exist on
`$REMOTE/{BASE}` itself (pre-existing), note them and continue; do not fix unrelated breakage.

If checks fail because of the merge and you cannot fix them → `needs-human` (do not commit).

## 5. Commit and push

Stage resolved files by path, then:

```bash
git commit -F - <<'EOF'
chore: merge {BASE} into {HEAD}

Resolve conflicts:
- <file>: <how it was resolved, one line each>

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
```

Push (no force):

- Same-repo: `git push $REMOTE HEAD:{HEAD}`
- Fork: `git push https://github.com/{HEAD_REPO}.git HEAD:{HEAD}`

If rejected as non-fast-forward (someone pushed meanwhile): fetch `{HEAD}` again, `git merge` it into
your worktree, resolve if needed, re-run checks, and push again — at most twice, then `needs-human`.

On success, remove the worktree: `cd {REPO_ROOT} && git worktree remove "$WT"`.
On `needs-human`, **leave the worktree in place** (with the in-progress merge) for the user.

## 6. Final report

End with exactly this block (the parent parses it):

```
RESULT: resolved | needs-human | skipped
PR: #{PR}
CONFLICTED_FILES:
- <path>: <resolution summary, or the open question for needs-human>
CHECKS: <commands run and pass/fail; note pre-existing failures>
COMMIT: <full sha pushed, or none>
WORKTREE: <path if left behind, or removed>
NOTES: <anything the user should know>
```
