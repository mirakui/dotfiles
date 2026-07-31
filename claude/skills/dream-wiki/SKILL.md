---
name: dream-wiki
description: "~/.claude/wiki (naruta-mono docs/wiki) に溜まった知見を定期整備 (dreaming) する。重複ページの統合・リンク張り、古いページの陳腐化チェックと deprecated 化、横断パターンの「定石」ページへの蒸留を 1 回分の予算内で行い、LOG.md に dream エントリを残して直接 commit する。Use when the user invokes /dream-wiki, or says: dreaming して, wiki を整理して, wiki を dreaming, wiki の棚卸し, wiki をリファクタ, wiki 統合して, dream the wiki, consolidate wiki, wiki maintenance。update-wiki の最終報告で dreaming が推奨されたときもこれを使う。"
user-invocable: true
---

# Dream Wiki

`~/.claude/wiki` (= `~/work/naruta-mono/docs/wiki` への symlink) に溜まったページを定期整備する。
karpathy 系 llm-wiki の Lint を拡張した **dreaming** — 睡眠中の記憶統合のように、個別に ingest された知見を横断的に整理・統合・蒸留する。

設計の背景: naruta-mono `docs/design/naruta-mono/wiki-dreaming.md`

**戦略は「差分中心 + ローテーション」**: 前回 dreaming 以降に増えたページを作業の軸にし、陳腐化チェックだけを古い順ローテーションで少しずつ回す。毎回 wiki 全体を精読しない (1 回の作業量を総ページ数に依存させないため)。

## 安全ルール (全フェーズ共通)

- **ページの削除・カテゴリの廃止はしない**。無効化は frontmatter `status: deprecated` + INDEX 行への `(deprecated)` 明記まで
- 1 回の dreaming で内容を変更するページは **15 ページまで**、蒸留による新規ページは **1 ページまで**。溢れた候補は Step 6 の LOG エントリに「次回持ち越し」として書き残す
- マージで吸収したページは中身を「→ [[統合先slug]] に統合」の 1 行 (+frontmatter) に置き換えて残す (旧 slug への `[[link]]` を壊さないため)。INDEX からは吸収されたページの行を削除する
- wiki は AI 自発更新領域なので**書き込み前のユーザ確認は不要**。直接 commit し、結果を最後に報告する

## Step 0: 準備 — 差分の特定

1. `~/.claude/wiki/CLAUDE.md` を読む (運用ルールの source of truth。本 skill と食い違う場合は CLAUDE.md を優先)
2. `~/.claude/wiki/INDEX.md` を読む (全ページの見取り図)
3. LOG.md から前回 dreaming 以降の差分を特定する:

```bash
# 前回 dream 以降の create 件数 (dream エントリが無ければ全期間)
awk '/^## \[[0-9-]+\] dream \|/{n=0; next} /^## \[[0-9-]+\] create \|/{n++} END{print n+0}' ~/.claude/wiki/LOG.md
```

4. 前回 dream エントリ以降の LOG を読み、**新規 (create) / 更新 (update) されたページの一覧**を作る。これが Step 2 (統合) の主対象
5. 件数が少ない (目安 5 件未満) のに手動起動された場合は、その旨を伝えた上で Step 1 (Lint) と Step 3 (陳腐化) だけの軽量実行に切り替えてよい

## Step 1: Lint — 機械的整合チェック (全体・安価)

以下を機械的に検査し、見つかった問題はその場で直す:

```bash
cd ~/.claude/wiki
# INDEX に載っていない orphan ページ / INDEX にあるのに実体が無いリンク
for f in */[a-z]*.md; do grep -qF "($f)" INDEX.md || echo "orphan: $f"; done
grep -oE '\]\([a-z]+/[a-z0-9-]+\.md\)' INDEX.md | tr -d ']()' | grep -v '^category/slug\.md$' | while read -r p; do [ -f "$p" ] || echo "index-dead: $p"; done  # category/slug.md は INDEX 冒頭の記入例なので除外
# [[link]] 切れ (slug に対応するファイルが無い)
grep -rhoE '\[\[[a-z0-9-]+\]\]' */[a-z]*.md | sort -u | tr -d '[]' | while read -r s; do ls */"$s".md >/dev/null 2>&1 || echo "wikilink-dead: $s"; done
```

- frontmatter 必須フィールド (`title` / `category` / `tags` / `created` / `updated`) の欠落もチェックする
- orphan ページは INDEX に行を追加。dead link (INDEX にあるが実体が無い) は、まず LOG.md にそのページの create エントリが残っていないか確認する。**詳細な記録が残っていれば LOG.md から本文を復元する** (過去の ingest でページ本体の書き込みだけが漏れた可能性があるため)。記録が無い/復元すると内容の創作になる場合はリンクを外す (新規ページの創作はしない)

## Step 2: 統合 — 重複・近接ページのマージ / 分割 / リンク (差分中心)

Step 0 の差分ページそれぞれについて、INDEX 全体と突き合わせて次を判断する:

| 判断 | 条件 | 操作 |
|---|---|---|
| マージ | 既存ページと知見が実質同一 / 片方が他方の部分集合 | 内容を統合先に吸収。吸収元は「→ [[統合先]] に統合」化 |
| 分割 | 1 ページに複数の独立ノウハウが混在 (「1 ページ 1 ノウハウ」違反) | 分割して相互に `[[link]]` |
| 相互リンク | テーマが近いが知見は別 | 双方の「関連」セクションに `[[link]]` を追記 |
| 何もしない | 独立した知見 | — |

- 判断に迷うペアは**マージせず相互リンクに留める** (保守的に)
- タグや INDEX のサマリだけで判断せず、候補ペアは必ず両方のページ本文を読んでから決める
- 読み込みが重い場合 (候補が多い場合) は、候補ペアの本文比較を subagent に並列で任せてよい。ただし**マージ後の本文執筆はメインが行う** (知見の取捨選択を subagent にさせない)
- **差分が多い場合 (目安 15 件超)**: 全差分ページを本文レベルで突き合わせるのは非現実的なので、まず INDEX 全体からタグ・タイトルが近い候補をスクリーニングし、その候補だけ本文を読んで判断する。見なかった残りは Step 5 の LOG エントリに「持ち越し」として正直に記録する (全部見たかのように書かない)

## Step 3: 陳腐化チェック — ローテーションで 8〜10 ページ

1. 照合が最も古いページから 8〜10 ページを選ぶ。順序は **max(`updated`, `reviewed`) の古い順**:

```bash
cd ~/.claude/wiki
for f in */[a-z]*.md; do
  u=$(awk -F': ' '/^updated:/{print $2}' "$f"); r=$(awk -F': ' '/^reviewed:/{print $2}' "$f")
  latest=$u; [ -n "$r" ] && [ "$r" \> "$u" ] && latest=$r
  echo "$latest $f"
done | sort | head -10
```

2. 各ページを現実と照合する。観点: バージョン・仕様が今も正しいか (一次情報を確認)、参照先のリポジトリ構成・スクリプトが現存するか (naruta-mono の `repos/` を確認)、リンク先 PR/doc が生きているか
3. 結果に応じて:
   - **問題なし** → frontmatter に `reviewed: YYYY-MM-DD` を付ける (無ければ追加、あれば更新)。`updated` は触らない
   - **記述が古い** → 内容を更新し `updated` を今日にする
   - **前提が消滅** (ツール廃止・構成撤去等) → frontmatter `status: deprecated` + 冒頭に理由 1 行 + INDEX 行の先頭に `(deprecated)` を付ける
4. 照合に外部確認 (WebFetch / repos/ 精読) が必要でコストが高いものは、確認できた範囲で判断し、未確認の点はページ内に「要確認: ...」と明記する (誤って「確認済み」の顔をさせない)

## Step 4: 蒸留 — 横断「定石」ページの生成 (1 回 1 ページまで)

1. INDEX のタグを集計し、**同一テーマのページが 5 件以上**あるクラスタを探す:

```bash
grep -oE '\[[a-z0-9-]+\]' ~/.claude/wiki/INDEX.md | sort | uniq -c | sort -rn | head -15
```

2. `aws` / `terraform` / `iam` のような汎用タグはクラスタとして扱わない (テーマの解像度が粗すぎて定石にならない)。`bedrock-agentcore` / `opensearch` / `coder` のような**具体的テーマのタグ**からクラスタを選ぶ
3. 最も価値が高そうなクラスタを 1 つ選び、構成ページを読んで**横断的なパターン・定石・判断基準**を抽出する。個別ページの要約の羅列ではなく、「複数ページを並べて初めて見える規則」を書く (例: awscc 系 N ページ → 「awscc で AgentCore を Terraform 化するときの共通定石」)。**クラスタの全ページを機械的に構成ページにしない** — テーマの中核に関わるページだけを選び、関連はあるが主題が違うページは無理に含めず「関連」リンクに留める
4. 通常ページと同じ `_template.md` 構成で該当カテゴリに作成し、frontmatter に `type: distilled` を付け、構成ページ全てへ `[[link]]` を張る。構成ページ側の「関連」にも逆リンクを追記する
5. 適切なクラスタが無い回はスキップしてよい (無理に作らない)

## Step 5: 記録と commit

1. `INDEX.md` を全操作と整合させる (マージで消えた行の削除、蒸留ページの行追加、(deprecated) 付与)。**蒸留ページの行は先頭に `(定石)` を付けて通常ページと区別する** (例: `- [(定石) awscc で AgentCore...]`)
2. `LOG.md` 末尾に dream エントリを追記する:

```markdown
## [YYYY-MM-DD] dream | dreaming 実行 (第 N 回)

対象: 前回以降の create X 件。統合 Y 件 / 分割 Z 件 / 相互リンク W 件 / 陳腐化チェック V 件 (更新 a・deprecated b・reviewed c) / 蒸留「<タイトル>」。
持ち越し: <あれば列挙、なければ「なし」>
```

3. wiki の実体リポジトリ (naruta-mono) で wiki 配下の変更を直接 commit する (`docs: wiki dreaming (...)`。コミットメッセージ規約は通常どおり)
4. 最終報告: 実施した操作のサマリ (LOG エントリ相当) + 持ち越し + 気づいた構造的な課題 (INDEX 肥大等) をユーザに報告する

## 落とし穴

- **タグ・サマリだけ見てマージしない**。必ず両方の本文を読む。似た見出しでも知見の粒度・前提が違うことが多い
- **`updated` と `reviewed` を混ぜない**。`updated` = 内容変更、`reviewed` = 照合のみ。混ぜるとローテーションが壊れる
- **蒸留ページを量産しない**。1 回 1 ページ厳守。定石ページ自体が重複源になったら本末転倒 (数回運用して様子を見る)
- LOG.md は追記専用。過去エントリを書き換えない
