---
name: git-push-pr
description: "Git push & PR skill. Use when the user says: push, プッシュ, push and pr, PR作って, PR更新, プルリクエスト, create pr, update pr"
---

# Git Push & PR Skill

Use the **Task tool** with `subagent_type: "Bash"` to delegate all git/gh operations to a subagent. This keeps the main context clean — only the final summary is returned.

## Prompt for the Bash subagent

Pass the following prompt to the Task tool:

~~~
You are a git push & PR assistant. Execute the following steps using Bash commands.

## Step 1: Gather context

Run these commands in parallel to understand the current state:

```bash
git status --short
git branch --show-current
git log --oneline -10
git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "NO_UPSTREAM"
```

- If the current branch is `main` or `master`, report "Cannot create PR from the default branch." and stop.

## Step 2: Determine base branch and diff

Detect the default branch:

```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
```

Then get the full diff from base:

```bash
git log --oneline <base-branch>..HEAD
git diff <base-branch>...HEAD --stat
```

## Step 3: Push

Push the current branch to origin with tracking:

```bash
git push -u origin HEAD
```

If the push fails, report the error and stop.

## Step 4: Check for existing PR

```bash
gh pr view --json number,title,url,body 2>/dev/null
```

- If a PR exists, go to **Step 5a** (update).
- If no PR exists, go to **Step 5b** (create).

## Step 5a: Update existing PR

Use the existing PR body (already fetched in Step 4 via `gh pr view --json body`) as the starting point.
Edit it based on the full diff from base branch and all commit messages — do NOT rewrite from scratch.

Rules:
- Preserve any hand-written content that is still accurate
- If any part of the existing body has drifted from the actual changes (e.g., outdated summary, stale test plan), overwrite that part to match the current state
- Update the `## Summary` section to reflect the current state of ALL changes from base branch
- Update the `## Test plan` section if needed
- If the body is empty, create a new one using the format below

Format (for new or empty body):

```
## Summary
<1-3 bullet points describing ALL changes from base branch>

## Test plan
<bulleted checklist of testing TODOs>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Update the PR body:

```bash
gh pr edit <number> --body "$(cat <<'EOF'
<edited pr body>
EOF
)"
```

Then output the summary and stop.

## Step 5b: Create new PR

Analyze the full diff from base branch and all commit messages to draft a PR title and body.

Rules:
- PR title: 日本語で書く。70文字以内で簡潔に変更内容を説明する
- PR body: written in English, same format as Step 5a

Create the PR:

```bash
gh pr create --draft --title "<title>" --body "$(cat <<'EOF'
<pr body>
EOF
)"
```

## Step 6: Report

Output a summary in this exact format:

```
## PR Summary
- **Action**: <Created | Updated>
- **Title**: <PR title>
- **URL**: <PR URL>
- **Branch**: <current branch> → <base branch>
- **Commits**: <number of commits>
```
~~~

## Important

- Always use `subagent_type: "Bash"` so the git/gh output stays in the subagent context
- After receiving the subagent result, display the summary to the user
