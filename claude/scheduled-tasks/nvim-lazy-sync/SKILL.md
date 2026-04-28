---
name: nvim-lazy-sync
description: Neovim の lazy.nvim プラグインを定期的に sync し、lazy-lock.json の差分があれば dotfiles にコミット
---

dotfiles の Neovim プラグインを最新化します。次の手順を順に実行してください。

1. lazy.nvim の sync を headless 実行:

   ```bash
   nvim --headless "+Lazy! sync" +qa
   ```

2. lazy-lock.json に差分があるか確認:

   ```bash
   git -C /Users/naruta/src/dotfiles diff --quiet -- nvim/lazy-lock.json
   ```

3. 終了コードが非 0 (差分あり) の場合のみ、dotfiles にコミット (push はしない):

   ```bash
   git -C /Users/naruta/src/dotfiles add nvim/lazy-lock.json
   git -C /Users/naruta/src/dotfiles commit -m "chore: sync nvim lazy plugins"
   ```

4. 結果 (更新の有無、エラーがあればその概要) を簡潔に報告してください。