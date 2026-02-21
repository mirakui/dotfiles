# GitHub Repo Launcher

よく開く GitHub リポジトリを補完して選んでブラウザで開く Raycast 拡張。

## セットアップ

```bash
cd raycast/github-repo-launcher
pnpm install
pnpm run dev
```

Raycast の設定画面から「Extensions」を開き、`+` → 「Import Extension」でこのディレクトリを指定する。

## コマンド

### Open Repository

登録済みリポジトリの一覧を表示する。よく使うリポジトリが上位に表示される（frecency ソート）。

| アクション | ショートカット |
|---|---|
| ブラウザで開く | Enter |
| URL をコピー | Cmd+Shift+C |
| owner/repo をコピー | Cmd+Opt+C |
| ランキングをリセット | Cmd+Shift+R |
| リストから削除 | Ctrl+X |

### Add Repository

リポジトリを追加する。以下の形式に対応:

- `owner/repo`
- `github.com/owner/repo`
- `https://github.com/owner/repo`
