---
name: finish-session
description: "セッションを終了するときに、そのセッションでユーザが求めていたゴールと実際に行ったことを要約表示し、得られた再利用可能な知見を wiki に記録してセッションを締める。あわせて、残っている bd（beads）タスク・完了した plan/hitl 文書・このセッションで作った worktree があれば整理し、naruta-mono ではこのセッションの docs と .beads の更新をコミットする（自動で安全に処理できるものは確認なし、判断が要る部分だけ askme で確認）。それ以外でユーザへの問いかけは行わず、finish-session した時点でセッションは成功とみなす。Use when the user invokes /finish-session, or says: セッション終了, セッションを終わりにする, セッションを締める, 今日はここまで, 終わりにする, このセッション終了して, finish session, end session, wrap up the session, セッションまとめて終わる"
user-invocable: true
---

# Finish Session

このスキルは作業セッションを締めくくるための end-of-session ワークフロー。
今のセッションでユーザが何を達成したかったのか、それに対して何をやったのかを要約して提示し、
セッションで得た再利用可能な知見を wiki に記録してセッションを締める。
あわせて、このセッションで生じた後始末（bd タスク・plan/hitl 文書・docs/.beads のコミット・worktree）を整理する。

**このスキルは原則としてユーザへの問いかけ（質問・確認）を行わない。** finish-session が呼ばれた時点でセッションは成功とみなし、終了理由のヒアリングや Linear Issue 等への新規登録は行わない。**例外は後始末の判断が要る部分だけ**で、次の 3 つに限り askme で確認する: (1) 最新化後に残った bd タスクの扱い（Step 1）、(2) 完了か不明な plan/hitl 文書（Step 2）、(3) 安全に削除できない worktree（Step 6）。自動で安全に処理できるもの（完了が明白な bd タスクの close、完了済み plan/hitl の archive、naruta-mono での docs/.beads コミット、安全条件を満たす worktree 削除）は確認なしで行う。後始末の対象が一切無ければ、このスキルは一切問いかけをしない。

会話履歴に強く依存するため、要約・知見抽出に加えて、bd タスクの進捗最新化・plan/hitl の完了判定・このセッションで触れた docs の選別・worktree 特定もサブエージェントに委譲せず、メインエージェントが直接実行する。会話の文脈を持っているメインエージェントだけが、ゴール・得られた知見・各タスクや文書の実態を正確に言い当てられるため。（例外として、wiki への確定済みの書き込みだけは Step 4 が呼ぶ `update-wiki` 経由で background の sub-agent に委譲される。）

## Step 1: bd タスクの確認・進捗最新化・残タスクの確認

最初に、このセッションのワークスペースに bd（beads）タスクが残っているかを確認する。

### 1-1. 検出

`bd list` で未完了（open / in_progress）のタスクを取得する。

```bash
bd list   # デフォルトで closed を除外。--all は付けない
```

`bd` が「no beads database found」等でワークスペースを解決できない、または未完了タスクが 0 件の場合は、**このステップを丸ごとスキップして Step 2 に進む。**

### 1-2. 進捗の最新化（askme なし・自動）

会話履歴を読み返し、各 bd タスクの実態に合わせて状態を更新する。**ここはユーザに確認せず、メインエージェントの判断で自動的に行う。**

- 今セッションで **完了したと判断できるタスクは自動で close する**（`bd close <id>`）。
- 着手したが未完のタスクは in_progress にする（`bd update <id> --claim`）。
- 進捗・経緯で残しておきたいことは notes に追記する（`bd update <id> --append-notes "..."`）。
- 実態に変化がないタスクは触らない。

### 1-3. 残タスクの確認（askme・タスクごとに個別判断）

最新化のあとに残った未完了タスク（open / in_progress）を、**1 件ずつ** `AskUserQuestion`（askme）で提示し、それぞれの扱いを聞く。残タスクが複数あるときは **1 タスク = 1 設問** として、最大 4 件ずつ束ねて 1 回の呼び出しにまとめる（4 件を超えるなら複数回に分ける）。

各タスクの選択肢は次を基本とする（文脈に応じて調整してよい）:

- **そのまま残す**: open のまま次セッションへ持ち越す。
- **defer する**: `bd update <id> --defer <when>` で一時的に ready から外す（後回し）。
- **close する**: もう不要 / やらないので閉じる（`bd close <id>`）。

ユーザの回答に従って `bd` を更新する。bd を操作した結果（自動 close・指示による close/defer・残置）は Step 7 の最終報告に含める。`.beads/` の変更は naruta-mono では Step 5 でコミットされる。

## Step 2: plan / hitl ドキュメントの archive

現在のワークスペース（リポジトリ）に `docs/plans/` または `docs/hitl/` があれば、完了した文書を `archive/` へ片付ける。

### 2-1. 検出

リポジトリルート（`git rev-parse --show-toplevel`）配下に `docs/plans/` / `docs/hitl/` が存在するか確認する。**どちらも無ければこのステップをスキップして Step 3 へ。**

- 対象は各ディレクトリ直下の active な文書（`YYYYMMDD-<slug>.md`）のみ。`archive/`（既存のアーカイブ）・`_template.md`・`CLAUDE.md`・`.gitkeep` は除外する。

### 2-2. 完了判定

各文書の `**Status**:` 行・本文の完了条件・会話の文脈を見て、完了したかを判断する。**完了判定の基準と archive の運用（移動先ディレクトリ名を含む）は、そのリポジトリの `docs/CLAUDE.md`（および `docs/hitl/CLAUDE.md`）を source of truth とする。** 典型的には「文書に書かれた完了条件（HITL は『完了確認』）を満たした」または「対応 PR がマージされた」時点で完了とみなす。

### 2-3. アーカイブ / 確認

- **完了が明確な文書** → `archive/` に `git mv` する（askme なし）。

  ```bash
  git mv docs/plans/<file>.md docs/plans/archive/
  git mv docs/hitl/<file>.md  docs/hitl/archive/
  ```

- **完了か不明な文書** → `AskUserQuestion`（askme）で **1 文書ずつ**「archive する / そのまま残す」を聞く（複数あれば最大 4 件ずつ束ねる）。回答に従い archive する／残す。
- **明らかに未完了の文書** → 何もしない（残す。問いかけもしない）。

### 2-4. コミットの扱い

このステップでは `git mv` でステージするだけに留め、ここではコミットしない。**naruta-mono では、この archive 移動を含む docs 変更を後続の Step 5 でまとめてコミットする。** それ以外のリポジトリではステージのみで残し、コミットはユーザ / 別フローに任せる。移動した文書は Step 7 の報告に載せる。

## Step 3: セッションを振り返って要約する

会話の最初から現在までを読み返し、次の2点を整理してユーザに提示する。これは確認を求めるものではなく、締めくくりとして見せる要約。

- **ゴール (Goal)**: このセッションでユーザが達成したかった中核的な目的は何か。1〜数行で言い切る。途中で目的が変わった/追加された場合は、その変遷も書く。
- **行ったこと (What was done)**: ゴールに対して実際に何をやったか。完了したこと・確認できたこと・まだ途中のことを区別して箇条書きにする。

次のフォーマットで表示する:

```markdown
## セッションの振り返り

### 🎯 ゴール
<ユーザが達成したかったこと>

### ✅ 行ったこと
- <やったこと / 完了状況>
- ...

### 🚧 未完了・気になっている点（あれば）
- <まだ終わっていないこと>
```

要約は推測で埋めず、実際の会話に基づいて書く。ゴールが曖昧なまま終わったセッションなら「ゴールが明示されなかった」と正直に書く。この要約は次の Step 4（wiki 記録）で知見を抽出する土台にもなるので、得られた学びや未完了点を取りこぼさないことが重要。

## Step 4: セッションの知見を wiki に記録する

このセッションで得た再利用可能な知見を wiki に記録する。記録ロジックは `update-wiki` skill に集約されているので、**`update-wiki` skill を Skill ツールで呼び出して** 行う（手順を二重管理しないため）。

- 呼び出す前に、要約（Step 3）と会話全体から「今回新しく理解したこと・次に活かせる知見」を念頭に置く。`update-wiki` はそのセッション文脈をもとに知見を抽出する。
- `update-wiki` の中では、**知見の抽出はメインエージェントが行い、確定後のファイル書き込み（ページ作成/更新・`INDEX.md` / `LOG.md` 追記）は background の sub-agent に委譲される**。そのため呼んだ時点ではまだ書き込みが進行中のことがある。書き込みの **完了通知を待ってから** 次の Step 5（コミット）に進む（wiki への書き込みが docs/wiki 配下に確定してからコミットしたいため）。
- この wiki は「AI が自発的に更新してよい」領域なので **事前確認は不要**。`update-wiki` が `~/.claude/wiki` に直接書き込み、`INDEX.md` / `LOG.md` も更新する。
- 記録に値する知見が無いセッション（雑談のみ、ごく短い作業など）では、`update-wiki` 側がスキップ判断する（sub-agent は起動しない）。空ページは作らない。

`update-wiki` が記録/更新したページ（new / updated）を、Step 7 の報告に含める。

## Step 5: naruta-mono の docs / .beads をコミットする

**このステップは naruta-mono リポジトリでのみ実行する。** それ以外のリポジトリではスキップして Step 6 へ。push はしない（コミットのみ）。

### 5-1. 判定

現在の作業ツリーの remote が `ivry-inc/naruta-mono` かを確認する（worktree でも同じ remote なので検出できる）。

```bash
git remote get-url origin   # git@github.com:ivry-inc/naruta-mono.git なら対象
```

naruta-mono でなければこのステップをスキップする。

### 5-2. 対象の選別（このセッションで触れた docs のみ + .beads）

会話の文脈から、**このセッションで作成 / 編集 / archive した docs ファイル**を列挙し、それらと `.beads/` の更新だけを add する。`git add docs`（配下を一括）はしない — このセッション由来でない既存の未コミット docs 変更を巻き込まないため、ファイルを明示して add する。

主な対象: Step 1（bd → `.beads/issues.jsonl` / `interactions.jsonl` 等）、Step 2（plan/hitl の `git mv`）、Step 4（`update-wiki` による `docs/wiki/` 配下）でこのセッションが生じさせた変更。

```bash
git add <このセッションで触れた docs ファイル...> .beads
```

- `.beads/` は `.beads/.gitignore` が backup/ や proxieddb/ 等を除外するので `git add .beads` でよい（追跡対象の `issues.jsonl` / `interactions.jsonl` / `metadata.json` が入る）。

### 5-3. 1 コミットにまとめる

docs と .beads を **1 コミット** で行う。beads の git hooks（pre-commit / prepare-commit-msg 等）が走るので **`--no-verify` は付けない**。

- メッセージは **簡潔な Conventional Commits**。プロンプトの列挙はしない（session-end の housekeeping コミットのため）。例:

  ```
  docs: wrap up session (archive plans/hitl, wiki & beads updates)
  ```

- add 対象が無ければ（docs も .beads も差分なし）コミットしない。

コミットした内容（コミットハッシュ・対象の概要）は Step 7 の報告に載せる。

## Step 6: このセッションの worktree のクリーンアップ

このセッションで作成 / 使用した git worktree のうち、作業が完了したものを削除する。**対象はこのセッションに紐づく worktree のみ**で、`git worktree list` 全体の一掃はしない。

### 6-1. 対象の特定

会話の文脈（このセッションで `git worktree add` / EnterWorktree 等で worktree を作った、またはその中で作業した）から、このセッションに紐づく worktree を特定する。**該当が無ければこのステップをスキップして Step 7 へ。**

### 6-2. 安全条件の判定

対象 worktree ごとに、次を **すべて** 満たすか確認する:

- 未コミットの変更が無い（`git -C <worktree> status --porcelain` が空）
- 未 push のコミットが無い
- ブランチが main にマージ済み、またはリモートで消滅（gone）している

### 6-3. 削除 / 確認

- **安全条件をすべて満たす** → `git worktree remove <path>` で自動削除する（askme なし）。
  - 現在のセッションがその worktree 内で動いている場合、worktree は自分自身を remove できない。main の作業ツリー（`git worktree list` の先頭）に `cd` してから `git worktree remove <path>` する。
- **安全条件を満たさない**（未コミット変更・未 push・未マージ等がある） → 自動削除せず、`AskUserQuestion`（askme）で「削除する（`git worktree remove --force`）/ 残す」を聞く（複数あれば最大 4 件ずつ束ねる）。

削除した worktree（と残した worktree）は Step 7 の報告に載せる。

## Step 7: 結果を報告する

```markdown
## セッション終了

- **bd タスクの整理**（対象があった場合のみ）:
  - close: `<id>` <タイトル>
  - defer: `<id>` <タイトル>（〜まで）
  - 残置: `<id>` <タイトル>
- **plan / hitl の archive**（対象があった場合のみ）:
  - archived: `docs/plans/<file>.md` → `archive/`
  - 残置: `docs/hitl/<file>.md`（未完了 / 判断保留）
- **docs / .beads のコミット**（naruta-mono で対象があった場合のみ）:
  - `<commit hash>` `docs: ...` — docs <n> ファイル + .beads
- **worktree のクリーンアップ**（対象があった場合のみ）:
  - removed: `<path>`（merged など）
  - 残置: `<path>`（未コミット変更あり 等）
- **wiki に記録した知見**:
  - `<category/slug.md>` — <1 行サマリ>（new / updated）
  - ...
```

対象が無かった項目は省略する。wiki に記録すべき知見も無かった場合は、その旨だけ簡潔に報告して締める。

## 注意

- **このスキルは原則ユーザへの問いかけを行わない。** 終了理由のヒアリングも、Linear Issue 等への新規登録も行わない。finish-session した時点でセッションは成功とみなす。**唯一問いかけるのは後始末の判断が要る部分だけ**（残った bd タスクの扱い=Step 1 / 完了不明な plan/hitl=Step 2 / 安全に消せない worktree=Step 6）で、後始末の対象が無ければ問いかけは一切しない。
- 自動で安全に処理できるものは確認なしで行う: 完了が明白な bd タスクの **自動 close**（Step 1）、完了済み plan/hitl の **`git mv` での archive**（Step 2）、naruta-mono での **docs/.beads のコミット**（Step 5、push はしない）、安全条件を満たす worktree の **自動 `git worktree remove`**（Step 6）。判断が割れるもの（残タスク・完了不明文書・未コミット/未マージ worktree）は askme で確認する。
- **コミットは naruta-mono に限る**（Step 5）。検出は remote が `ivry-inc/naruta-mono` か否か。add するのは **このセッションで触れた docs ファイルと `.beads`** のみで、`git add docs` の一括はしない（他由来の未コミット変更を巻き込まないため）。docs と .beads は 1 コミットにまとめ、メッセージは簡潔な Conventional Commits（プロンプト列挙なし）。beads の hooks を活かすため `--no-verify` は使わない。push はしない。
- 後始末の各ステップ（bd 進捗最新化 / plan-hitl 完了判定 / このセッションで触れた docs の選別 / worktree 特定）と要約・知見抽出は、会話履歴を読んで判断する作業なのでサブエージェントに委譲せずメインエージェントが直接行う。例外は wiki への記録で、Step 4 が呼ぶ `update-wiki` の中で、確定済みの書き込みだけが background の sub-agent に委譲される。
- plan/hitl・コミット・worktree の各ステップは、現在のワークスペースに対象が無ければ丸ごとスキップする（`docs/plans`・`docs/hitl` が無い／naruta-mono でない／このセッション紐づきの worktree が無い場合は何もしない）。
- wiki への知見記録（Step 4）は毎回行う。ただし記録に値する知見が無ければ `update-wiki` 側でスキップしてよい。
- wiki は事前確認なしで自発的に書く（wiki CLAUDE.md がそれを許可）。保存先は常に `~/.claude/wiki` に固定。更新手順はその dir の `CLAUDE.md` を source of truth とし、本スキルの要約と食い違う場合は CLAUDE.md を優先する。ページ作成・更新時は `INDEX.md` への 1 行追加と `LOG.md` への追記を必ずセットで行う。
