---
name: update-wiki
description: "現在のセッション/作業で得た再利用可能な知見を ~/.claude/wiki に記録(Ingest)する。更新方法は wiki dir の CLAUDE.md に従い、ページ作成/更新・INDEX.md への追加・LOG.md への追記をセットで行う。Use when the user invokes /update-wiki, or says: wikiに記録, wikiに残して, wiki更新, wiki更新して, ナレッジに残して, ナレッジ化, この学びをwikiに, 知見を残して, 今の学びを記録, record to wiki, update wiki, save to knowledge base. finish-session の知見記録ステップからもこの skill が呼ばれる。"
user-invocable: true
---

# Update Wiki

このスキルは、いま行った作業（このセッション）から **再利用可能な知見** を抽出し、`~/.claude/wiki` に記録（Ingest）するためのもの。
karpathy 系 llm-wiki パターンに沿って、ページの作成/更新と `INDEX.md` / `LOG.md` の更新をセットで行う。

`finish-session` skill の知見記録ステップからも、この skill が Skill ツール経由で呼ばれる。単体でも「wiki に記録して」等で起動できる。

会話の文脈を持っているメインエージェントだけが知見を正確に言い当てられるため、**知見の抽出はメインエージェントが直接行う**。一方、抽出が確定したあとの **機械的な書き込み（ページのファイル作成/更新・`INDEX.md` / `LOG.md` の追記）は会話文脈を必要としない** ので、ここだけを background の sub-agent に委譲し、メインを早く解放する。

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

## Step 3: 書き込み指示書を組み立てる（メインエージェント）

抽出した各知見について、**文脈を持たない sub-agent がそのまま機械的に書き込めるレベル** の指示を作る。要約や「適宜」で渡さず、ページ本文は全文を用意する（sub-agent に知見の創作・取捨選択をさせないため）。

各知見について次を決める:

1. **カテゴリ**（`troubleshooting` / `tools` / `workflow` / `infra` / `codebase`）。該当が無ければ wiki CLAUDE.md の方針に従って新カテゴリを足す（その場合 CLAUDE.md のカテゴリ表と `INDEX.md` 見出しを更新する指示も指示書に含める）。
2. **ファイルパス** `<category>/<kebab-slug>.md` と **new / update** の区別（Step 1 で読んだ `INDEX.md` で既存ページの有無を判断する）。
3. **ページ本文**:
   - new の場合: `~/.claude/wiki/_template.md` の構成に沿った frontmatter（`title` / `category` / `tags` / `created` / `updated`、必要に応じ `related_repos` / `sources`）＋本文の **全文**。
   - update の場合: 既存ページのどこに何を追記/修正するか（追記本文の全文と、`updated` を今日に直す指示）。
4. **リンク**: wiki 内の関連ページへは `[[slug]]`（拡張子なし）、wiki 外（research/design/PR など）へは相対パス / フル URL。
5. **`INDEX.md` 追記行**: 該当カテゴリ見出しの下に足す `- [タイトル](category/slug.md) — 1 行サマリ`（末尾に `` `[tags]` `` を添えてよい）。update でサマリが変わるなら直す行も指定する。
6. **`LOG.md` 追記行**: 末尾に足す `## [YYYY-MM-DD] <create|update> | <タイトル>` ＋ 何をしたか・出どころ（PR / session など）1〜2 行。

> 日付（`YYYY-MM-DD`）は sub-agent 側で `date +%F` を実行して埋めさせる。

## Step 4: 書き込みを background の sub-agent に委譲する

Step 3 の指示書を渡し、**Agent ツールを `run_in_background: true` で起動** してファイル書き込みだけを sub-agent に任せる。メインはここで解放され、完了通知を受け取ったら Step 5 で最終報告する。

sub-agent へのプロンプトには次を必ず含める:

- 「**指示書のとおりに `~/.claude/wiki` 配下へ機械的に書き込む。知見の取捨選択・内容の創作はしない**」と明記する。
- 各ページの書き込み（new は新規作成、update は既存ファイルを Read してから Edit）。
- `INDEX.md` への 1 行追加と `LOG.md` への追記を **必ずセットで** 行う（片方だけにしない）。これを忘れると orphan ページが残る。
- 日付は `date +%F` で取得して frontmatter / `LOG.md` に埋める。
- 完了後、**書き込んだ/更新したページの一覧（`<category/slug.md>` と new/update）を結果として返す**。

記録に値する知見が無くスキップする場合は sub-agent を起動せず、Step 5 でその旨だけ報告する。

## Step 5: 結果を報告する

sub-agent を起動した直後は「書き込みを background で実行中」であることを伝える。sub-agent の **完了通知を受け取ったら**、その結果をもとに最終報告する:

```markdown
## wiki 更新

- `<category/slug.md>` — <1 行サマリ>（new / updated）
- ...
```

記録すべき知見が無くスキップした場合は、「記録に値する知見が無いと判断したためスキップした」とだけ簡潔に伝える。

最終報告の際、前回 dreaming 以降の新規ページ数を数え、**15 件以上なら dreaming (`/dream-wiki` skill) の実行を推奨する 1 行を報告に添える**:

```bash
awk '/^## \[[0-9-]+\] dream \|/{n=0; next} /^## \[[0-9-]+\] create \|/{n++} END{print n+0}' ~/.claude/wiki/LOG.md
```

## 注意

- 更新手順は `~/.claude/wiki/CLAUDE.md` を source of truth とし、本スキルの記述と食い違う場合は CLAUDE.md を優先する。
- ページ作成/更新時は `INDEX.md` への 1 行追加と `LOG.md` への追記を **必ずセットで** 行う。これを忘れると wiki が orphan ページだらけになる。
- 1 ページ 1 ノウハウを守る。1 ページが大きくなりすぎたら分割し `[[...]]` でつなぐ。
- **知見の抽出・取捨選択（Step 1〜3）は会話文脈に依存するため、必ずメインエージェントが直接行う。** background sub-agent に渡すのは、確定済みの指示書どおりに書き込む機械作業（Step 4）だけ。抽出まで sub-agent に丸投げしない。
