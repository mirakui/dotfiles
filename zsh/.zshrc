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
alias be='bundle exec'
alias bc='bundle console'
alias bo='bundle open'
function c() { code $(git rev-parse --show-toplevel) }
alias i='i2cssh'
alias a='$HOME/src/awssh/exe/awssh'
alias gl='git ls-files'
alias chrome-canary="/Applications/Google\ Chrome\ Canary.app/Contents/MacOS/Google\ Chrome\ Canary"

# https://gist.github.com/3103708
function git-branches-by-commit-date() {
  for branch in `git branch -r | grep -v HEAD`; do
    echo -e `git show --format='%ai %ar by %an' $branch | head -n 1` \t$branch;
  done | sort -r
}
function ssh-config-grep() {cat ~/.ssh/config | grep --color -A1 ${1}}
function git-show-current-branch() {
  git rev-parse --abbrev-ref HEAD
}
function git-create-temporary-branch() {
  local bname=`ruby -e 'puts Time.now.strftime("naruta/tmp/%Y%m%d-%H%M%S")'`
  git checkout -b $bname
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

if [ -x "$HOMEBREW_PREFIX/bin/starship" ]; then
  # https://github.com/starship/starship
  eval "$(starship init zsh)"
else
  autoload promptinit
  promptinit
  prompt adam2
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
# AWS
############################################################

function aws-ssh() {
  local rds_flag=false
  local bastion_instance_id
  local rds_endpoint
  local ssh_port=19922
  local rds_local_port=15432
  local rds_remote_port=5432

  for arg in "$@"; do
    case "$arg" in
      --rds) rds_flag=true ;;
      -p=*) ssh_port="${arg#*=}" ;;
      --rds-local-port=*) rds_local_port="${arg#*=}" ;;
      --rds-remote-port=*) rds_remote_port="${arg#*=}" ;;
    esac
  done

  bastion_instance_id=$(
    aws ec2 describe-instances \
      --filters "Name=instance-state-name,Values=running" \
      --query "Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key=='Name'].Value | [0]}" \
    | jq -r '.[][] | "\(.ID) \(.Name)"' \
    | fzf \
    | cut -d' ' -f1
  )

  if $rds_flag; then
    rds_endpoint=$(
      aws rds describe-db-instances \
        --query 'DBInstances[?DBInstanceStatus==`available`].[Endpoint.Address]' \
        --output text \
      | fzf
    )
    aws ec2-instance-connect ssh \
      --ssh-port=${ssh_port} \
      --local-forwarding ${rds_local_port}:${rds_endpoint}:${rds_remote_port} \
      --instance-id=${bastion_instance_id}
  else
    aws ec2-instance-connect ssh \
      --ssh-port=${ssh_port} \
      --instance-id=${bastion_instance_id}
  fi
}

############################################################
# external environments
############################################################

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
    #BUFFER="vi ${files}"
    #zle accept-line
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
export JAVA_HOME=/Library/Java/JavaVirtualMachines/amazon-corretto-17.jdk/Contents/Home
export ANDROID_SDK_ROOT=~/Library/Android/sdk
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
export PATH=$PATH:$ANDROID_SDK_ROOT/emulator
export PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin
function android_clean_cache() { rm -i -rf ~/.gradle/caches/transforms-2 && ./gradlew clean && ./gradlew --stop && rm -i -rf ~/.gradle/caches/build-cache-* }

# Volta
if [ -d $HOME/.volta ]; then
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"
fi

# PostgreSQL
if [ -d $HOMEBREW_PREFIX/opt/libpq/bin ]; then
  export PATH="$HOMEBREW_PREFIX/opt/libpq/bin:$PATH"
fi

# gcloud
export GCLOUD_SDK_DIR="/opt/google-cloud-sdk"
if [ -f "$GCLOUD_SDK_DIR/path.zsh.inc" ]; then . "$GCLOUD_SDK_DIR/path.zsh.inc"; fi
if [ -f "$GCLOUD_SDK_DIR/completion.zsh.inc" ]; then . "$GCLOUD_SDK_DIR/completion.zsh.inc"; fi

# Enable startup time profiler:
# zprof

if [ -f $HOME/.zshrc.secret ]; then source $HOME/.zshrc.secret; fi
if [ -f $HOME/.zshrc.work ]; then source $HOME/.zshrc.work; fi


### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/naruta/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
