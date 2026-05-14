---
name: save-as-skill
description: "現在の会話履歴からタスクパターンを抽出して、新しい Claude skill (SKILL.md) として保存する。セッション終わりに今回のような依頼を再利用したいときに使う。Use when the user says: skill にして保存, save as skill, save this as a skill, このタスクを skill に, セッションを skill にして, 今回のような依頼を skill にして, skill 化して, スキル化して, capture as skill, この作業を skill 化, 今のやり取りを skill に, 同じことを次もできるように skill にして"
---

# Save As Skill

このスキルは「今のセッションを次回も再現できるようにスキルとして残す」ための **メタスキル** です。
これまでの会話で実際に行ったタスク (要件、使ったツール、ユーザからの訂正、最終的にうまくいったやり方) を 1 つの `SKILL.md` に蒸留して保存します。

スキル名と保存スコープはユーザに `AskUserQuestion` で確認します。会話履歴とユーザの好みに依存するため、サブエージェントには委譲せず、メインエージェントが直接実行します。

## Step 1: セッションを分析する

会話の最初から現在までを見直し、次の 5 点を頭の中で整理する。後の SKILL.md の本文の素材になる。

- **What**: ユーザが達成したかった中核タスクは何か (1 行で言い切れる粒度まで抽象化する)
- **How**: 実際に使ったツール、コマンド、ファイル、外部サービス、サブエージェント。順序も込みで記録する
- **Corrections**: ユーザからの訂正・フィードバック (「そうじゃなくて」「これは要らない」など)。"うまくいかなかった経路" は同じくらい価値がある
- **I/O**: 期待される入力 (引数、ファイル形式) と出力 (フォーマット、保存先、戻り値) の形
- **Triggers**: ユーザが今回どんな日本語/英語の言い回しでこの依頼を始めたか。それの類語も列挙する

これらは後で `description` のトリガーフレーズと、本文のステップとして使う。

## Step 2: スキル名を 1 つ推薦する

中核タスクを表す **kebab-case** の名前を 1 つ生成する。

ガイドライン:
- 「動詞 + 目的語」または「目的語 + 動詞」の形 (例: `release-note-draft`, `migrate-rails-route`, `convert-csv-to-parquet`)
- 英数字とハイフンのみ。20 文字以内が目安
- 命令的・行為的な名前にする (`-helper` `-utils` のような曖昧語は避ける)
- すでに同名スキルが存在しないかを確認する:

```bash
ls -d ~/.claude/skills/<候補名> "$(pwd)/.claude/skills/<候補名>" 2>/dev/null
```

衝突する場合は別名を選び直す。

## Step 3: 名前とスコープをユーザに確認する

`AskUserQuestion` で 2 つの質問を **同時に** 投げる。

- **Q1 「スキル名」**
  - 選択肢 1 つ目: `<推薦名> (Recommended)` を first option にする
  - 選択肢 2-3 つ目: 同義の別表現 (例: `session-to-skill`, `skill-from-session`)
  - ユーザは Other で自由入力できる
- **Q2 「保存スコープ」** (`header: "Scope"`)
  - `user`: `~/.claude/skills/<name>/SKILL.md` — 全プロジェクトで使える
  - `project`: `<cwd>/.claude/skills/<name>/SKILL.md` — このリポジトリでのみ使える

`AskUserQuestion` の `header` は 12 文字以内なので `"Skill name"` / `"Scope"` のように短く。

## Step 4: SKILL.md をドラフトする

### frontmatter

```yaml
---
name: <確定したスキル名>
description: "<1-2 文でスキルが何をするか>。Use when the user says: <日本語トリガー>, <英語トリガー>, ..."
---
```

description のコツ:
- 1 文目で「何をするスキルか」を端的に説明する
- 続けて「いつ発火させたいか」を、ユーザが使いそうなフレーズの形で **日英 5〜10 個** 列挙する
- Claude には skill を undertrigger する傾向があるので、やや push 気味の書きぶりにする (例: 「〜のときは必ずこの skill を使うこと」)

### 本文

skill-creator のガイドに沿って書く:

- **命令形 (imperative)** で書く。「〜してください」より「〜する」「〜を実行する」
- ステップ番号付きの見出しで区切る (`## Step 1: ...`)
- 各ステップで使うコマンド・ツール名は具体的に。曖昧な「適切に処理する」は避ける
- **Why を添える**: 「なぜそのステップが必要か」を 1 行入れる。LLM は理由が分かると edge case で正しく判断できる
- **ALWAYS / NEVER を多用しない**。どうしても外せないルールにだけ使い、それ以外は理由とともに柔らかく書く
- 入出力フォーマットがある場合は実例を 1-2 個示す
- 元セッションで意外と詰まったポイント、ユーザに訂正された点があれば「注意」として明示的に書き残す

### 構造のテンプレ

```markdown
---
name: <name>
description: <description>
---

# <Title>

<このスキルが何をするか、なぜ存在するかを 2-3 行で>

## Step 1: ...
## Step 2: ...
## Step N: 結果を報告する
```

## Step 5: 保存先のパスを決める

scope の選択に従い `<target>` を決める。

| Scope | パス |
|---|---|
| user | `${HOME}/.claude/skills/<name>/SKILL.md` |
| project | `${PWD}/.claude/skills/<name>/SKILL.md` |

注意:
- `~/.claude/skills` がユーザの dotfiles (例: `~/src/dotfiles/claude/skills`) へのシンボリックリンクになっていることがある。user スコープを選ぶと結果的に dotfiles リポジトリに反映される。これは想定通りの挙動。
- 同名ディレクトリが既に存在する場合、**上書きはせず** 必ず `AskUserQuestion` で「上書きするか / 別名を付けるか / 中止するか」を確認してから次へ進む。意図しない既存スキルの破壊を防ぐため。

## Step 6: 書き込みと報告

1. 親ディレクトリがなければ作成する: `mkdir -p <target の親>`
2. `Write` ツールで `<target>` に SKILL.md を書き込む (`cat` / `echo` / heredoc は使わず Write を使うこと)
3. 完了したら次のフォーマットで報告する:

```
## Saved skill
- **Name**: <name>
- **Scope**: <user | project>
- **Path**: <絶対パス>
- **Trigger phrases**: <description から代表的なもの 2-3 個>
- **Next steps**: 新しいセッションで関連フレーズを言ってトリガー動作を確認する
```

## 注意

- このスキル自体は会話履歴を読み取って自然言語で蒸留する作業なので、サブエージェントには委譲しない。メインエージェントが直接判断する。
- ユーザがすでに自分で名前を決めていそうな場合 (依頼文に「〜という名前で」と書かれているなど) は Step 2 の推薦より優先する。AskUserQuestion の Q1 では recommended としてその名前を出す。
- セッションが極端に短い、または雑談だけで具体的タスクがない場合は、ユーザに「保存する価値のあるタスクが見当たらないが、本当に保存するか?」を確認してから進める。空のスキルを量産しないため。
