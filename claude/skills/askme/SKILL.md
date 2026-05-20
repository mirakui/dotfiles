---
name: askme
description: "Force using the AskUserQuestion tool whenever Claude asks the user a question. Use when the user says: askme, ask me, アスクミー, 質問して, 聞いて, 確認して"
---

# Askme Skill

From the moment this skill is invoked until the conversation ends, or until the user explicitly cancels it, the following rules must be strictly observed.

## Purpose

Whenever Claude needs to ask the user a question that requires their judgment, the `AskUserQuestion` tool MUST be used. Writing questions in plain text output to prompt the user for an answer is completely forbidden.

## Question language

- Ask questions in Japanese (日本語). The question text, header labels, and option labels/descriptions passed to `AskUserQuestion` should all be written in Japanese.
- This skill's instructions are written in English, but the user-facing questions are not.

## Prohibited

- Writing interrogative forms in text output, such as `〜でしょうか？`, `〜しますか？`, `どちらにしますか？`, `どうしますか？`, `Should I ...?`, `Which one ...?`
- Presenting bulleted or numbered options in text output to implicitly solicit an answer
- Any out-of-tool inquiry that requires the user's judgment, including progress confirmation, direction/approach confirmation, implementation choices, naming consultations, and scope confirmation
- Conditional inquiries written as text, e.g. "Let me know if you want X" / 「もし◯◯なら教えてください」

## Required

- Call `AskUserQuestion` the moment a question becomes necessary
- Even when free-form answers are expected, prepare 2–4 options before calling `AskUserQuestion` whenever possible ("Other" is automatically appended by the tool, so completeness is not a concern)
- Batch related questions into a single tool call (up to 4 questions). Prefer batching over multiple sequential calls
- Keep each `header` label within 12 characters (e.g. `発動方式`, `命名規則`, `スコープ`)
- Keep each option's `label` to 1–5 words, and use `description` to explain trade-offs and meaning

## Scope

- Applies continuously from the moment this skill is invoked until the conversation session ends
- Remains in effect until the user explicitly cancels it (e.g. "askme 解除", "もうツールを使わなくていい")
- Does not apply to outputs that do not require user judgment, such as reports, explanations, or result presentations — only questions must go through the tool

## Exceptions

- Echoing back the user's answer immediately after they respond to an `AskUserQuestion` call is not a question, so plain text is fine
- `ExitPlanMode` at the end of plan mode is a separate tool and should still be used as-is
