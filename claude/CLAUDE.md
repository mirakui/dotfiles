# dotfiles

Personal dotfiles repository managing configurations for terminals, editors, keyboards, and AI tools.

## Directory Structure

```
.
├── bin/                  # Custom scripts and utilities
│   ├── ai-cmd            #   AI command utility
│   ├── aws-assume-role   #   AWS role switching
│   ├── aws-ecs-exec      #   AWS ECS execution
│   ├── aws-ssh           #   AWS SSH connection
│   ├── git-ai-commit     #   AI-powered git commit message generation
│   └── git-ai-pr         #   AI-powered git PR creation
├── claude/               # Claude Code configuration
│   ├── agents/           #   Agent definitions
│   ├── commands/         #   Custom commands
│   ├── contexts/         #   Context configurations
│   ├── rules/            #   Rule definitions
│   ├── scripts/          #   Utility scripts
│   ├── skills/           #   Skill definitions
│   └── settings.json     #   Claude Code settings
├── git/                  # Git configuration
│   ├── .gitconfig        #   Global git config
│   └── .gitignore_global #   Global gitignore
├── karabiner/            # Karabiner-Elements configuration (macOS key remapping)
│   ├── assets/           #   Complex modifications, etc.
│   └── karabiner.json    #   Main configuration
├── keyboard/             # Keyboard configuration
│   └── q11/              #   Keychron Q11 layout definitions
├── nvim/                 # Neovim configuration
│   ├── lua/              #   Lua config files (plugins, config)
│   ├── init.lua          #   Main initialization file
│   └── lazy-lock.json    #   Plugin lock file
├── tests/                # Test suite
│   ├── run.sh            #   Test runner
│   └── *_test.sh         #   Test scripts
├── tmux/                 # tmux configuration
│   └── .tmux.conf        #   tmux config file
├── vim/                  # Vim configuration
│   ├── .vim/             #   Plugins, etc.
│   ├── .vimrc            #   Main config
│   ├── .vimrc.plugins    #   Plugin config
│   └── .gvimrc           #   GUI Vim config
├── vscode/               # VS Code configuration
│   └── settings.json     #   Editor settings
├── wezterm/              # WezTerm configuration
│   └── wezterm.lua       #   Main config (Lua)
├── zellij/               # Zellij configuration
│   ├── config.kdl        #   Main config (KDL)
│   └── layouts/          #   Layout definitions
├── zsh/                  # Zsh configuration
│   ├── .zshrc            #   Main config
│   ├── ai-cmd.zsh        #   AI command plugin
│   └── starship.toml     #   Starship prompt config
├── CLAUDE.md -> claude/CLAUDE.md  # This file (symlink)
├── .gitmodules           # Git submodule definitions
├── .irbrc                # Ruby IRB config
└── .pryrc                # Pry (Ruby REPL) config
```
