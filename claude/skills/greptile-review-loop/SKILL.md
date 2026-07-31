---
name: greptile-review-loop
description: >-
  Read Greptile review comments on a PR, fix issues, commit, push, reply to comments, and
  re-request review in a loop until no issues remain. Takes a PR number as argument. Trigger on
  "greptile", "review loop", "fix greptile", "greptile review", "address greptile comments".
user-invocable: true
argument-hint: <PR number>
---

# Greptile Review Loop

Fix all Greptile review comments on a PR in an automated loop.

## Input

PR number from argument. Derive `{owner}/{repo}` from the current git remote.

## Workflow

Repeat the following loop until Greptile has no new comments:

### 1. Wait for Greptile Review

First check the current status:

```bash
gh pr checks <PR> || true
```

`gh pr checks` exits non-zero whenever any check is still pending or failing, so append `|| true` when you only want to read its output.

If "Greptile Review" is already `pass` or `fail`, proceed to step 2.

Otherwise use the **Monitor tool** to wait. Pass an `until` loop that exits once the check both *exists* and is no longer pending:

```bash
until [ "$(gh pr checks <PR> --json name,bucket \
  --jq '[.[] | select(.name == "Greptile Review" and .bucket != "pending")] | length')" = "1" ]; do
  sleep 20
done
```

Test `bucket`, not `state`: `state` moves `PENDING` → `IN_PROGRESS` → `SUCCESS`, so a "not PENDING" test succeeds while the review is still running and you read a half-finished review.

Monitor streams each line back as a notification and fires when the loop exits — do not poll manually or chain `sleep` calls.

### 2. Fetch Greptile Comments

```bash
gh api repos/{owner}/{repo}/pulls/{PR}/comments \
  --jq '[.[] | select(.user.login == "greptile-apps[bot]" and .in_reply_to_id == null)]'
```

For each comment, extract: `id`, `path`, `line`, `body`, `created_at`.

`in_reply_to_id == null` keeps only thread-opening comments, since replies inside a thread are discussion rather than new findings.

Filter to only **new** comments by keeping the set of comment `id`s you have already replied to and treating anything else as new. Do not compare `created_at` against the last push: findings you already fixed stay in the list forever, so timestamps alone cannot tell handled from unhandled. On the first iteration, all comments are new.

### 3. Check for New Comments

If 0 new comments: report "Greptile review complete — no new issues" and **exit the loop**.

If comments exist: list them as a summary table (priority, file, one-line description) before fixing.

### 4. Fix Issues

For each comment:
1. Read the file at the indicated path and line
2. Understand the issue from the comment body (look for priority badges: P0 = must fix, P1 = should fix, P2 = consider)
3. Apply the fix
4. P0 and P1 issues must be fixed. P2 issues should be fixed if straightforward; skip with justification if not.

### 5. Verify

Run the project's lint, format, and test commands. Fix any failures before proceeding.

Typical commands (adapt to the project):
- `pnpm format && pnpm lint && pnpm test`
- `mise run backend:test`

### 6. Commit & Push

Stage changed files individually (never `git add -A`). Commit with a descriptive message:

```
fix: address greptile review feedback

- <summary of each fix>

Co-Authored-By: Claude <noreply@anthropic.com>
```

Then `git push`.

Record the commit short hash for step 7.

### 7. Reply to Comments

For each fixed comment, post a reply:

```bash
gh api repos/{owner}/{repo}/pulls/{PR}/comments/{comment_id}/replies \
  -f body="Fixed in {short_hash}. {brief description of fix}"
```

For skipped P2 comments, reply explaining why it was skipped.

### 8. Re-request Review

```bash
gh pr comment <PR> --body "@greptileai review"
```

Greptile takes up to a minute to register the re-requested run. Before looping back, confirm the check has actually returned to `pending` — until it does, the *previous* run's `pass` is still listed and step 1's wait exits immediately on it, making you re-read findings you just fixed.

### 9. Loop

Go back to step 1.

## Notes

- Maximum 5 iterations to avoid infinite loops. If issues persist after 5 rounds, report remaining issues and stop.
- Do not modify files outside the scope of Greptile's comments unless necessary to fix a reported issue.
- If a comment is on code you didn't write in this PR, flag it to the user instead of fixing.
