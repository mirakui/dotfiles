---
name: devin-loop
description: >-
  Run a plan on Devin in the cloud to open a PR, then loop until the plan is satisfied and Greptile
  has no remaining issues — reviewing the PR, triggering Greptile, and having Devin (not Claude) fix
  every gap. Takes a plan as argument (file path or inline text). Trigger on "devin", "devin loop",
  "devin でPR", "プランをdevinに", "devin にプラン投げて", "run on devin", "devin cloud".
user-invocable: true
argument-hint: <plan file path | inline plan text>
---

# Devin Loop

Hand a plan to **Devin** (cloud agent) to implement and open a PR, then loop: review the PR against
the plan, run **Greptile** on it, and feed every gap back to **Devin** until the plan is fully
satisfied with no outstanding Greptile issues.

**Claude never edits code here.** All fixes are made by Devin via session messages. Claude only
orchestrates, reviews, and relays feedback.

## Input

- **Argument = the plan.** If the argument is a path to an existing file, read that file as the plan.
  Otherwise treat the whole argument text as the inline plan.
- Derive `{owner}/{repo}` and the current branch from the git remote.

## Preflight

1. **Load Devin MCP tools** (they are deferred):
   ```
   ToolSearch  select:mcp__devin__devin_session_create,mcp__devin__devin_session_interact
   ```
   If nothing is returned, the `devin` MCP server is connected at the CLI level but its tools are not
   loaded in this session. Run `claude mcp list` to confirm `devin: https://mcp.devin.ai/mcp ✔ Connected`,
   then tell the user to **restart the session** so the tools load, and stop. Do NOT fall back to
   curl/the v1 API — this skill is MCP-only.
2. Confirm `gh` is authenticated (`gh auth status`).

## Workflow

Loop steps 2–4. **Hard cap: 5 rounds.**

### 1. Create the Devin session

Call `mcp__devin__devin_session_create` with a `prompt` that contains the full plan plus explicit
instructions. The exact parameter names come from the loaded tool schema; the prompt must tell Devin to:

- Implement the plan in repo `{owner}/{repo}`.
- Run the project's tests / lint / build and make them pass.
- Open a **draft** pull request when done, base branch = the repo default branch.

Record the returned `session_id` and session URL, and show both to the user.

### 2. Wait for Devin to finish and produce a PR

Poll `mcp__devin__devin_session_interact` (get-status / get-session-details action) until
`status_enum` is `finished` or `blocked` **and** a `pull_request` URL exists.

- Devin cloud runs take several minutes. Between polls, wait with a **background timer** — foreground
  `sleep` is blocked, so run `sleep 120` with `run_in_background: true` and re-poll when it exits.
- If `status_enum` is `blocked` (Devin is asking a question) and there is no PR yet: read its latest
  message. Answer it via `devin_session_interact` (send-message) if you can do so from the plan;
  otherwise surface the question to the user and stop.

Record the PR number and URL.

### 3. Review the PR

**3a. Plan conformance (Claude).** Run `gh pr diff <PR>` and `gh pr view <PR>`. Check the diff against
every item in the plan. Produce a concrete list of gaps (missing items, deviations, untested areas),
or conclude there are none.

**3b. Greptile.** Check `gh pr checks <PR>` for `Greptile Review`.

- If it has **not** run on the current head commit (absent, or stale from before Devin's latest push),
  **trigger it**: `gh pr comment <PR> --body "@greptileai review"`.
- Wait for it to complete with a **Monitor** until-loop (do not chain `sleep`):
  ```bash
  until gh pr checks <PR> --json name,state \
    --jq '.[] | select(.name == "Greptile Review") | .state' \
    | grep -vq PENDING; do sleep 30; done
  ```
- Fetch Greptile comments:
  ```bash
  gh api repos/{owner}/{repo}/pulls/{PR}/comments \
    --jq '[.[] | select(.user.login == "greptile-apps[bot]")]'
  ```
  Keep only **new** comments (created after Devin's last push). Note priorities: P0 = must fix,
  P1 = should fix, P2 = consider.

See the sibling `greptile-review-loop` skill for more on the Greptile check/comment mechanics.

### 4. Decide and route feedback

- **Done** when there are **no plan gaps AND no new Greptile comments** → report the PR URL and exit.
- Otherwise, compile **one** feedback message containing:
  - the plan gaps from 3a, and
  - the Greptile comments from 3b, each with `file:line` and priority.

  Send it to the **same** Devin session via `mcp__devin__devin_session_interact` (send-message),
  instructing Devin to fix everything and push to the existing PR. Optionally reply to each addressed
  Greptile comment (append ` (claude)` to the reply body). Then go back to **step 2**.

### 5. Safety cap

If 5 rounds pass without convergence, stop and report: remaining plan gaps, outstanding Greptile
comments, the PR URL, and the Devin session URL so the user can continue manually.

## Quick reference

| Action | How |
|---|---|
| Create session | `mcp__devin__devin_session_create` (prompt = plan + instructions) |
| Poll status / send feedback | `mcp__devin__devin_session_interact` |
| Wait for Devin | `sleep 120` with `run_in_background: true`, re-poll on exit |
| Trigger Greptile | `gh pr comment <PR> --body "@greptileai review"` |
| Wait for Greptile | Monitor until-loop on `gh pr checks <PR>` |
| Review against plan | `gh pr diff <PR>` / `gh pr view <PR>` |

## Common mistakes

- **Claude fixing the code itself.** Don't. Every fix — plan gaps and Greptile comments alike — goes
  to Devin via a session message.
- **Polling with foreground `sleep`.** It's blocked; use a background timer or Monitor.
- **Re-reviewing before Devin pushed.** After sending feedback, wait for Devin to finish (step 2) and
  re-trigger Greptile on the new head commit before re-reviewing.
- **Counting stale Greptile comments as new.** Filter to comments created after Devin's latest push.
- **Adding ` (claude)` to the trigger comment.** Keep `@greptileai review` clean so the mention fires;
  only human-readable replies get the ` (claude)` suffix.
