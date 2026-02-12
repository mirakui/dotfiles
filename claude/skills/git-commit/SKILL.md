---
name: git-commit
description: "Git commit skill. Use when the user says: commit, コミット, save and commit, 変更をコミット, コミットして, save, セーブ"
---

# Git Commit Skill

Use the **Task tool** with `subagent_type: "Bash"` to delegate all git operations to a subagent. This keeps the main context clean — only the final summary is returned.

## Prompt for the Bash subagent

Pass the following prompt to the Task tool:

~~~
You are a git commit assistant. Execute the following steps using Bash commands.

## Step 1: Check for changes

Run `git status --short`.

- If there is no output (working tree clean), report "No changes to commit." and stop.

## Step 2: Inspect changes

Run these commands to understand what changed:

```
git diff --staged
git diff
git log --oneline -5
```

## Step 3: Stage files

Stage the relevant changed files using specific filenames:

```
git add <file1> <file2> ...
```

Rules:
- NEVER use `git add -A` or `git add .`
- Skip files that look sensitive (.env, credentials, secrets, tokens, private keys)
- If sensitive files are detected, list them and note they were skipped

## Step 4: Create commit message

Analyze the staged diff and write a conventional commit message.

Format:
```
<type>: <description>

<optional body>
```

- Types: feat, fix, refactor, docs, test, chore, perf, ci
- Description: concise, lowercase, imperative mood, always in English
- Body: only if the change needs explanation, always in English
## Step 5: Commit

Use HEREDOC format to commit:

```bash
git commit -m "$(cat <<'EOF'
<type>: <description>

<optional body>

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

If the commit fails because a pre-commit hook (formatter, linter, etc.) modified files:

1. Re-stage the same files from Step 3: `git add <file1> <file2> ...`
2. Retry the commit with the same message
3. Retry only once — if it fails again, report the error and stop

## Step 6: Report

After the commit succeeds, output a summary in this exact format:

```
## Commit Summary
- **Message**: <the commit message first line>
- **Files**: <list of committed files>
- **Hash**: <short hash from git log --oneline -1>
```
~~~

## Important

- Always use `subagent_type: "Bash"` so the git output stays in the subagent context
- After receiving the subagent result, display the summary to the user
- If the user wants to push, ask for confirmation before running `git push`
