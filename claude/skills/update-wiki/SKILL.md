---
name: update-wiki
description: "現在のセッション/作業で得た再利用可能な知見を ~/.claude/wiki に記録(Ingest)する。更新方法は wiki dir の CLAUDE.md に従い、ページ作成/更新・INDEX.md への追加・LOG.md への追記をセットで行う。Use when the user invokes /update-wiki, or says: wikiに記録, wikiに残して, wiki更新, wiki更新して, ナレッジに残して, ナレッジ化, この学びをwikiに, 知見を残して, 今の学びを記録, record to wiki, update wiki, save to knowledge base. finish-session の知見記録ステップからもこの skill が呼ばれる。"
user-invocable: true
---

# Update Wiki

このスキルは、いま行った作業（このセッション）から **再利用可能な知見** を抽出し、`~/.claude/wiki` に記録（Ingest）するためのもの。
karpathy 系 llm-wiki パターンに沿って、ページの作成/更新と `INDEX.md` / `LOG.md` の更新をセットで行う。

`finish-session` skill の知見記録ステップからも、この skill が Skill ツール経由で呼ばれる。単体でも「wiki に記録して」等で起動できる。

会話の文脈を持っているメインエージェントだけが知見を正確に言い当てられるため、サブエージェントには委譲せず、メインエージェントが直接実行する。

## 前提: 記録先と確認の要否

- 記録先は常に `~/.claude/wiki`（`~/work/naruta-mono/docs/wiki` への symlink。中身は同じ）。作業対象がどのプロジェクトでも、個人の中央 wiki としてここに集約する。
- この wiki は「AI が適宜・自発的に更新してよい」領域なので、**書き込み前のユーザ確認は不要**。直接書き込み、結果を最後に報告する。

## Step 1: wiki の方針と既存ページを読む

1. **`~/.claude/wiki/CLAUDE.md` を読む。** これが更新手順の source of truth。以下のステップの要約と食い違う場合は CLAUDE.md を優先する。
2. **`~/.claude/wiki/INDEX.md` を読む**（Query）。同じ知見の既存ページがないかを確認する。あれば新規作成せず、そのページを更新する（重複ページを作らないため）。

## Step 2: 再利用可能な知見を抽出する

会話・作業を振り返り、次に活かせる知見を抜き出して **1 ページ 1 ノウハウ** に分解する。

- 判断基準は「**次の作業で、すぐ引っ張り出したいか?**」。Yes のものだけ記録する。
- 調査の生ログや経緯ではなく、**定石・落とし穴・tips・チェックリスト** のような再利用できる形にまとめる。
- 記録に値する知見が無い場合（雑談のみ、ごく短い作業など）は **無理にページを作らず終了する**。空ページを量産しないため。その旨を Step 5 で報告する。

## Step 3: ページを作成 / 更新する

各知見について:

1. カテゴリを選ぶ（`troubleshooting` / `tools` / `workflow` / `infra` / `codebase`）。該当が無ければ wiki CLAUDE.md の方針に従って新カテゴリを足し、CLAUDE.md のカテゴリ表と `INDEX.md` の見出しも合わせて更新する。
2. **新規ページ**: `~/.claude/wiki/_template.md` の構成をコピーして `<category>/<kebab-slug>.md` に作る。frontmatter（`title` / `category` / `tags` / `created` / `updated`、必要に応じて `related_repos` / `sources`）を埋める。日付は実行時の日付を使う（`date +%F` で取得）。
3. **既存ページ更新**: 本文を追記・修正し、frontmatter の `updated` を今日の日付にする。
4. wiki 内の関連ページへは `[[slug]]`（拡張子なしのファイル名）でリンクする。wiki 外（research/design/PR など）へは相対パス / フル URL でリンクする。

## Step 4: INDEX.md と LOG.md を更新する（必須・セットで）

ページの作成/更新と必ずセットで行う。片方だけ更新しない。

- **`INDEX.md`**: 該当カテゴリ見出しの下に 1 行追加する。`- [タイトル](category/slug.md) — 1 行サマリ`（末尾に `` `[tags]` `` を添えてよい）。既存ページ更新でサマリが変わる場合は該当行も直す。
- **`LOG.md`**: 末尾に追記する。`## [YYYY-MM-DD] <create|update> | <タイトル>` ＋ 何をしたか・出どころ（PR / session など）を 1〜2 行。**新しいものを下に追記する**。

## Step 5: 結果を報告する

記録したページを報告する:

```markdown
## wiki 更新

- `<category/slug.md>` — <1 行サマリ>（new / updated）
- ...
```

記録すべき知見が無くスキップした場合は、「記録に値する知見が無いと判断したためスキップした」とだけ簡潔に伝える。

## 注意

- 更新手順は `~/.claude/wiki/CLAUDE.md` を source of truth とし、本スキルの記述と食い違う場合は CLAUDE.md を優先する。
- ページ作成/更新時は `INDEX.md` への 1 行追加と `LOG.md` への追記を **必ずセットで** 行う。これを忘れると wiki が orphan ページだらけになる。
- 1 ページ 1 ノウハウを守る。1 ページが大きくなりすぎたら分割し `[[...]]` でつなぐ。
- 会話文脈に依存するため、サブエージェントには委譲せずメインエージェントが直接行う。
