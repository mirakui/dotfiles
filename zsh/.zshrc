# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# Enable startup time profiler:
# zmodload zsh/zprof

############################################################
# Performance optimization: Lazy loading helper
############################################################
# Helper function to create lazy-loading wrappers
# Usage: _lazy_load_cmd <command> <init_function>
function _lazy_load_cmd() {
  local cmd=$1
  local init_func=$2
  eval "function $cmd() {
    unfunction $cmd
    $init_func
    $cmd \"\$@\"
  }"
}

############################################################
# Basic environment
############################################################
VIM_PREFIX=/usr

if [[ -d /opt/brew ]]; then
  HOMEBREW_PREFIX=/opt/brew
elif [[ -d /opt/homebrew ]]; then
  HOMEBREW_PREFIX=/opt/homebrew
else
  HOMEBREW_PREFIX=/usr/local
fi

if [[ -x ${HOMEBREW_PREFIX}/bin/nvim ]]; then
  VIM_PATH=${HOMEBREW_PREFIX}/bin/nvim
else
  VIM_PATH=/usr/bin/vim
fi

export LANG=ja_JP.UTF-8
export EDITOR=$VIM_PATH
export PATH=$HOMEBREW_PREFIX/bin:$PATH
export PATH=/usr/local/bin:/opt/local/bin:$PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/src/dotfiles/bin:$PATH
export LESS='-R'


############################################################
# aliases
############################################################
setopt complete_aliases
alias vi=$VIM_PATH
alias ls='ls -lahFG'
alias where='command -v'
alias du='du -h'
alias df='df -h'
alias vz='vi ~/.zshrc; . ~/.zshrc'
alias vs='vi ~/.ssh/config'
alias vv='vi --clean ~/.vimrc'
alias vvp='vi --clean ~/.vimrc.plugins'
alias vh='sudo vi /etc/hosts && dscacheutil -flushcache'
alias vw='vi ~/.config/wezterm/wezterm.lua'
alias vcc='vi -p ~/.claude/settings.json ~/.claude/CLAUDE.md'
alias claude='AWS_PROFILE="" claude'
function gf() { git submodule foreach git --no-pager $*; git --no-pager $* }
#alias st='gf status -sbu'
alias st='gf status'
alias co='git checkout'
alias gg='gf grep -n -E'
alias gls='git ls-files'
function gp() { BRANCH=$(git rev-parse --abbrev-ref HEAD); git pull --rebase origin $BRANCH }
function gpp() { BRANCH=$(git rev-parse --abbrev-ref HEAD); git pull --rebase origin $BRANCH && git push origin $BRANCH }
alias tmux-chdir-here="pwd | xargs tmux set -g default-path"
alias tmux-copy-buffer="tmux show-buffer | pbcopy"
alias cds='cd $HOME/src'
alias cdsc='cd $HOME/scratch'
alias cddt='cd $HOME/src/dotfiles'
function cdr() { cd $(git rev-parse --show-toplevel) }
alias be='bundle exec'
alias bc='bundle console'
alias bo='bundle open'
function c() { code $(git rev-parse --show-toplevel) }
function cr() { cursor $(git rev-parse --show-toplevel) }
alias gl='git ls-files'
alias chrome-canary="/Applications/Google\ Chrome\ Canary.app/Contents/MacOS/Google\ Chrome\ Canary"

autoload zmv
alias zmv='noglob zmv'

############################################################
# prompt
############################################################

if [[ "$TERM_PROGRAM" = "WarpTerminal" ]]; then
  function zle() {}
else
  if [[ -x "$HOMEBREW_PREFIX/bin/starship" ]]; then
    # https://github.com/starship/starship
    # Cache starship init for faster startup
    _starship_cache="${XDG_CACHE_HOME:-$HOME/.cache}/starship_init.zsh"
    _starship_bin="$HOMEBREW_PREFIX/bin/starship"
    if [[ ! -f "$_starship_cache" ]] || [[ "$_starship_bin" -nt "$_starship_cache" ]]; then
      mkdir -p "${_starship_cache:h}"
      starship init zsh > "$_starship_cache"
    fi
    source "$_starship_cache"
    unset _starship_cache _starship_bin
  else
    autoload promptinit
    promptinit
    prompt adam2
  fi
fi

############################################################
# prompt
############################################################

HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt hist_ignore_all_dups hist_save_no_dups
setopt share_history
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt hist_ignore_space
setopt auto_list
setopt auto_pushd

bindkey -e
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end
# for zsh-4.3.10 or later
# http://subtech.g.hatena.ne.jp/secondlife/20110222/1298354852
bindkey "^R" history-incremental-pattern-search-backward
bindkey "^S" history-incremental-pattern-search-forward

# http://twitter.com/#!/bulkneets/status/159186827809529857
#bindkey -s ':q' "^A^Kexit\n"

############################################################
# auto complete (with caching for faster startup)
############################################################

autoload -Uz compinit
# Only regenerate .zcompdump once per day
_zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -n ${_zcompdump}(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
unset _zcompdump

autoload predict-on
#predict-on

setopt auto_cd
setopt correct
setopt list_packed
setopt complete_aliases
setopt COMPLETE_IN_WORD

zstyle ':completion:*' list-colors ''

## keep background processes at full speed
setopt NOBGNICE
## restart running processes on exit
setopt HUP

## never ever beep ever
setopt NO_BEEP

autoload -U colors
colors

############################################################
# custom environments
############################################################

function scratch-new() {
  base_dir=~/scratch
  today_dir=$(date '+%Y%m%d')
  if [ -n "$1" ]; then
    target_dir="${base_dir}/${today_dir}-$1"
  else
    target_dir="${base_dir}/${today_dir}"
  fi

  mkdir -p "${target_dir}"
  cd "${target_dir}"
}

export FZF_DEFAULT_OPTS="--layout reverse --border --height 20% --tac"

function git-branch-new() {
  echo -n "branch suffix: "
  read suffix
  branch_name="naruta/$(date '+%Y%m%d')_${suffix}"
  git checkout -b $branch_name
}

function g() {
  SELECTED=$(git ls-files $(git rev-parse --show-toplevel) | fzf)
  if [ -n "$SELECTED" ]; then
    vi $SELECTED
  fi
}

function G() {
  SELECTED=$(tree -L1 --noreport -fdi ~/src/ ~/work | sed "s=${HOME}=~=" | fzf)
  SELECTED=$(echo $SELECTED | sed "s=^~=${HOME}=")
  if [ -n "$SELECTED" ]; then
    cd $SELECTED
  fi
}

function d() {
  SELECTED=$(git ls-files $(git rev-parse --show-toplevel) | sed 's=[^/]*$==g' | sort | uniq | grep -v '^$' | fzf)
  if [ -n "$SELECTED" ]; then
    cd $SELECTED
  fi
}

function b() {
  SELECTED=$(git branch --format='%(refname:short)' | sort | fzf --tiebreak=index)
  if [ -n "$SELECTED" ]; then
    git switch $SELECTED
  fi
}

############################################################
# external environments
############################################################

# gpg
export GPG_TTY=$TTY

# rbenv (lazy loading for faster startup)
export PATH=$HOME/.rbenv/bin:$PATH
if [[ -x $HOME/.rbenv/bin/rbenv ]]; then
  export PATH="$HOME/.rbenv/shims:$PATH"
  function _init_rbenv() {
    eval "$(rbenv init - zsh --no-rehash)"
  }
  _lazy_load_cmd ruby _init_rbenv
  _lazy_load_cmd gem _init_rbenv
  _lazy_load_cmd bundle _init_rbenv
  _lazy_load_cmd rails _init_rbenv
  _lazy_load_cmd irb _init_rbenv
  _lazy_load_cmd rake _init_rbenv
fi

# awssh
export AWSSH_PERCOL=$HOMEBREW_PREFIX/bin/peco
export AWSSH_CSSH=tmux-cssh


# golang
export GOPATH=$HOME/gocode
export GOROOT=$HOMEBREW_PREFIX/opt/go/libexec
export PATH=$GOPATH/bin:$PATH

# gcutil
# https://cloud.google.com/sdk/#Quick_Start# The next line enables shell command completion for gcloud.
# source "$HOME/google-cloud-sdk/completion.zsh.inc"

# pyenv (lazy loading for faster startup)
if [[ -d $HOME/.pyenv ]]; then
  export PYENV_ROOT=$HOME/.pyenv
  export PATH=$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH
  function _init_pyenv() {
    eval "$(pyenv init - --no-rehash)"
  }
  _lazy_load_cmd python _init_pyenv
  _lazy_load_cmd python3 _init_pyenv
  _lazy_load_cmd pip _init_pyenv
  _lazy_load_cmd pip3 _init_pyenv
fi

# node
export PATH=$HOME/.nodebrew/current/bin:$PATH

# deno
export PATH=$HOME/.deno/bin:$PATH

# vscode
if [ -d /Applications/Visual\ Studio\ Code.app ]; then
  export PATH=/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin:$PATH
fi


# tmux-cssh
export PATH=$HOME/src/github.com/zinic/tmux-cssh:$PATH

# rancher
export PATH=$HOME/.rd/bin:$PATH

# Android
export JAVA_HOME=/Library/Java/JavaVirtualMachines/amazon-corretto-21.jdk/Contents/Home
export ANDROID_HOME=$HOME/.android
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
export PATH=$PATH:$ANDROID_SDK_ROOT/emulator
export PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin
function android_clean_cache() { rm -i -rf ~/.gradle/caches/transforms-2 && ./gradlew clean && ./gradlew --stop && rm -i -rf ~/.gradle/caches/build-cache-* }

# Java
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# Volta
if [ -d $HOME/.volta ]; then
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"
fi

# PostgreSQL
if [ -d $HOMEBREW_PREFIX/opt/libpq/bin ]; then
  export PATH="$HOMEBREW_PREFIX/opt/libpq/bin:$PATH"
fi

# MySQL
if [ -d $HOMEBREW_PREFIX/opt/mysql-client@8.4/bin ]; then
  export PATH="$HOMEBREW_PREFIX/opt/mysql-client@8.4/bin:$PATH"
fi

# gcloud (defer completion loading)
export GCLOUD_SDK_DIR="/opt/google-cloud-sdk"
if [[ -f "$GCLOUD_SDK_DIR/path.zsh.inc" ]]; then
  . "$GCLOUD_SDK_DIR/path.zsh.inc"
fi
# Defer gcloud completion loading
if [[ -f "$GCLOUD_SDK_DIR/completion.zsh.inc" ]]; then
  function _init_gcloud_completion() {
    unfunction gcloud 2>/dev/null
    . "$GCLOUD_SDK_DIR/completion.zsh.inc"
  }
  _lazy_load_cmd gcloud _init_gcloud_completion
fi

# mise (lazy loading for faster startup)
if [[ -x ~/.local/bin/mise ]]; then
  export PATH="$HOME/.local/share/mise/shims:$PATH"
  function _init_mise() {
    eval "$(~/.local/bin/mise activate zsh)"
  }
  _lazy_load_cmd mise _init_mise
  alias mx='mise x --'
fi

# direnv (lazy loading for faster startup)
if [[ -x ~/.local/share/mise/shims/direnv ]]; then
  function _init_direnv() {
    eval "$(~/.local/share/mise/shims/direnv hook zsh)"
  }
  # direnv needs to hook into cd, so we lazy-load on first cd
  function _direnv_hook_cd() {
    unfunction _direnv_hook_cd
    _init_direnv
    # Re-trigger direnv for current directory
    _direnv_hook 2>/dev/null || true
  }
  # Defer direnv initialization
  function chpwd() {
    if (( $+functions[_direnv_hook] )); then
      _direnv_hook
    else
      _direnv_hook_cd
    fi
  }
fi

# Claude Code
alias claude="$HOME/.local/bin/claude"

# Enable startup time profiler:
# zprof

if [ -f $HOME/.zshrc.secret ]; then source $HOME/.zshrc.secret; fi
if [ -f $HOME/.zshrc.work ]; then source $HOME/.zshrc.work; fi


# Amazon Q post block. Keep at the bottom of this file.
#[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"

# pnpm
export PNPM_HOME="/Users/naruta/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/naruta/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# Added by Antigravity
export PATH="/Users/naruta/.antigravity/antigravity/bin:$PATH"

# bun (defer completion loading)
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
if [[ -s "$HOME/.bun/_bun" ]]; then
  function _init_bun_completion() {
    unfunction bun 2>/dev/null
    source "$HOME/.bun/_bun"
  }
  _lazy_load_cmd bun _init_bun_completion
fi
