# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# Enable startup time profiler:
# zmodload zsh/zprof

VIM_PREFIX=/usr

if [ -d /opt/brew ]; then
  HOMEBREW_PREFIX=/opt/brew
elif [ -d /opt/homebrew ]; then
  HOMEBREW_PREFIX=/opt/homebrew
else
  HOMEBREW_PREFIX=/usr/local
fi

if [ -x ${HOMEBREW_PREFIX}/bin/nvim ]; then
  VIM_PATH=${HOMEBREW_PREFIX}/bin/nvim
else
  VIM_PATH=/usr/bin/vim
fi

export LANG=ja_JP.UTF-8
export EDITOR=$VIM_PATH
export PATH=$HOMEBREW_PREFIX/bin:$PATH
export PATH=/usr/local/bin:/opt/local/bin:$PATH
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
alias be='bundle exec'
alias bc='bundle console'
alias bo='bundle open'
function c() { code $(git rev-parse --show-toplevel) }
function cr() { cursor $(git rev-parse --show-toplevel) }
alias gl='git ls-files'
alias chrome-canary="/Applications/Google\ Chrome\ Canary.app/Contents/MacOS/Google\ Chrome\ Canary"

function git-branch-new() {
  echo -n "branch suffix: "
  read suffix
  branch_name="naruta/$(date '+%Y%m%d')_${suffix}"
  git checkout -b $branch_name
}
function git-push-current-branch-to-origin() {
  local bname=`git rev-parse --abbrev-ref HEAD`
  git push origin $bname
}

autoload zmv
alias zmv='noglob zmv'

############################################################
# prompt
############################################################

if [ "$TERM_PROGRAM" != "WarpTerminal" ]; then
  if [ -x "$HOMEBREW_PREFIX/bin/starship" ]; then
    # https://github.com/starship/starship
    eval "$(starship init zsh)"
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
# auto complete
############################################################

autoload -U compinit
compinit

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

############################################################
# external environments
############################################################

# gpg
export GPG_TTY=$TTY

# rbenv
export PATH=$HOME/.rbenv/bin:$PATH
if [ -x $HOME/.rbenv/bin/rbenv ]; then
eval "$(rbenv init - zsh)"
fi

# awssh
export AWSSH_PERCOL=$HOMEBREW_PREFIX/bin/peco
export AWSSH_CSSH=tmux-cssh

# peco
function peco-git-ls-open() {
  local files=`git ls-files | peco --prompt "git ls-files>"`
  if [ -n "$files" ]; then
    BUFFER="vi ${files}"
    zle accept-line
    BUFFER="${BUFFER}${files}"
    zle redisplay
  fi
}
zle -N peco-git-ls-open
bindkey '^G' peco-git-ls-open

function peco-git-change-branch() {
  local branch=`git branch | peco --prompt "git branch>" | tr -d ' *'`
  if [ -n "$branch" ]; then
    BUFFER="${BUFFER}${branch}"
    zle redisplay
  fi
}
zle -N peco-git-change-branch
bindkey '^G^B' peco-git-change-branch

# golang
export GOPATH=$HOME/gocode
export GOROOT=$HOMEBREW_PREFIX/opt/go/libexec
export PATH=$GOPATH/bin:$PATH

# gcutil
# https://cloud.google.com/sdk/#Quick_Start# The next line enables shell command completion for gcloud.
# source "$HOME/google-cloud-sdk/completion.zsh.inc"

# pyenv
if `which pyenv > /dev/null`; then
  export PYENV_ROOT=$HOME/.pyenv
  export PATH=$PYENV_ROOT/bin:$PATH
  eval "$(pyenv init -)"
  #eval "$(pyenv virtualenv-init -)"
fi

# node
export PATH=$HOME/.nodebrew/current/bin:$PATH

# deno
export PATH=$HOME/.deno/bin:$PATH

# vscode
if [ -d /Applications/Visual\ Studio\ Code.app ]; then
  export PATH=/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin:$PATH
fi

# ghq
function peco-src () {
  local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N peco-src
bindkey '^]' peco-src

# tmux-cssh
export PATH=$HOME/src/github.com/zinic/tmux-cssh:$PATH

# rancher
export PATH=$HOME/.rd/bin:$PATH

# Android
# export JAVA_HOME=/Library/Java/JavaVirtualMachines/amazon-corretto-17.jdk/Contents/Home
# export ANDROID_SDK_ROOT=~/Library/Android/sdk
# export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
# export PATH=$PATH:$ANDROID_SDK_ROOT/emulator
# export PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin
# function android_clean_cache() { rm -i -rf ~/.gradle/caches/transforms-2 && ./gradlew clean && ./gradlew --stop && rm -i -rf ~/.gradle/caches/build-cache-* }

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

# gcloud
export GCLOUD_SDK_DIR="/opt/google-cloud-sdk"
if [ -f "$GCLOUD_SDK_DIR/path.zsh.inc" ]; then . "$GCLOUD_SDK_DIR/path.zsh.inc"; fi
if [ -f "$GCLOUD_SDK_DIR/completion.zsh.inc" ]; then . "$GCLOUD_SDK_DIR/completion.zsh.inc"; fi

# mise
if [ -x ~/.local/bin/mise ]; then
  eval "$(~/.local/bin/mise activate zsh)"
  alias mx='mise x --'
fi

# direnv
if [ -x ~/.local/share/mise/shims/direnv ]; then
  eval "$(~/.local/share/mise/shims/direnv hook zsh)"
fi

# Claude Code
alias claude="$HOME/.claude/local/claude"

# Enable startup time profiler:
# zprof

if [ -f $HOME/.zshrc.secret ]; then source $HOME/.zshrc.secret; fi
if [ -f $HOME/.zshrc.work ]; then source $HOME/.zshrc.work; fi


### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/naruta/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# Amazon Q post block. Keep at the bottom of this file.
#[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"
