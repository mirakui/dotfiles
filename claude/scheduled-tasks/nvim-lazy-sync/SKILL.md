---
name: nvim-lazy-sync
description: Neovim の lazy.nvim プラグインを定期的に sync し、lazy-lock.json の差分があれば dotfiles にコミット
---

dotfiles の Neovim プラグインを最新化します。次のスクリプトを実行してください。

```bash
/Users/naruta/src/dotfiles/bin/nvim-lazy-sync
```

このスクリプト (`dotfiles/bin/nvim-lazy-sync`) は以下を自動で行います。

1. `nvim --headless "+Lazy! sync" +qa` でプラグインを sync
2. `nvim/lazy-lock.json` に差分があるか確認
3. 差分があれば `chore: sync nvim lazy plugins` でコミット（push はしない）
4. 差分がなければコミットせず終了 (exit 0)

スクリプトの終了コードと標準エラー出力をもとに、結果（更新の有無、エラーがあればその概要）を簡潔に報告してください。
