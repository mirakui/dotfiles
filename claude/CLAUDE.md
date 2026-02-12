# dotfiles

個人用の設定ファイル(dotfiles)リポジトリ。ターミナル、エディタ、キーボード、AI ツールなどの設定を管理する。

## ディレクトリ構成

```
.
├── bin/                  # カスタムスクリプト・ユーティリティ
│   ├── ai-cmd            #   AI コマンドユーティリティ
│   ├── aws-assume-role   #   AWS ロール切り替え
│   ├── aws-ecs-exec      #   AWS ECS 実行
│   ├── aws-ssh           #   AWS SSH 接続
│   ├── git-ai-commit     #   AI による git commit メッセージ生成
│   └── git-ai-pr         #   AI による git PR 作成
├── claude/               # Claude Code の設定
│   ├── agents/           #   エージェント定義
│   ├── commands/         #   カスタムコマンド
│   ├── contexts/         #   コンテキスト設定
│   ├── rules/            #   ルール定義
│   ├── scripts/          #   ユーティリティスクリプト
│   ├── skills/           #   スキル定義
│   └── settings.json     #   Claude Code 設定ファイル
├── git/                  # Git の設定
│   ├── .gitconfig        #   グローバル git 設定
│   └── .gitignore_global #   グローバル gitignore
├── karabiner/            # Karabiner-Elements の設定 (macOS キーリマップ)
│   ├── assets/           #   Complex modifications など
│   └── karabiner.json    #   メイン設定ファイル
├── keyboard/             # キーボード設定
│   └── q11/              #   Keychron Q11 のレイアウト定義
├── nvim/                 # Neovim の設定
│   ├── lua/              #   Lua 設定ファイル (plugins, config)
│   ├── init.lua          #   メイン初期化ファイル
│   └── lazy-lock.json    #   プラグインロックファイル
├── tests/                # テストスイート
│   ├── run.sh            #   テストランナー
│   └── *_test.sh         #   各種テストスクリプト
├── tmux/                 # tmux の設定
│   └── .tmux.conf        #   tmux 設定ファイル
├── vim/                  # Vim の設定
│   ├── .vim/             #   プラグインなど
│   ├── .vimrc            #   メイン設定
│   ├── .vimrc.plugins    #   プラグイン設定
│   └── .gvimrc           #   GUI Vim 設定
├── vscode/               # VS Code の設定
│   └── settings.json     #   エディタ設定
├── wezterm/              # WezTerm の設定
│   └── wezterm.lua       #   メイン設定 (Lua)
├── zellij/               # Zellij の設定
│   ├── config.kdl        #   メイン設定 (KDL)
│   └── layouts/          #   レイアウト定義
├── zsh/                  # Zsh の設定
│   ├── .zshrc            #   メイン設定
│   ├── ai-cmd.zsh        #   AI コマンドプラグイン
│   └── starship.toml     #   Starship プロンプト設定
├── CLAUDE.md -> claude/CLAUDE.md  # このファイル (シンボリックリンク)
├── .gitmodules           # Git サブモジュール定義
├── .irbrc                # Ruby IRB 設定
└── .pryrc                # Pry (Ruby REPL) 設定
```
