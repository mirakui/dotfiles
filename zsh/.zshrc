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
alias st='gf status'
alias br='gf branch'
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

autoload promptinit
promptinit
prompt adam2


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


############################################################
# auto complete
############################################################


## keep background processes at full speed
setopt NOBGNICE
## restart running processes on exit
setopt HUP

## never ever beep ever
setopt NO_BEEP

autoload -U colors
colors

############################################################
# precmd / preexec
############################################################
local COMMAND=""
local COMMAND_TIME=""
autoload -Uz vcs_info
zstyle ':vcs_info:*' formats '(%s)-[%b]'
zstyle ':vcs_info:*' actionformats '(%s)-[%b|%a]'
#RPROMPT="%1(v|%F{green}%1v%f|) %F{blue}[%*]%f"

# https://www.themoderncoder.com/add-git-branch-information-to-your-zsh-prompt/
function precmd() {
  vcs_info
}
RPROMPT=\$vcs_info_msg_0_

if [ -x $HOMEBREW_PREFIX/bin/growlnotify ]; then
  function precmd_growl() {
    if [ "$TERM" = "screen" ] ; then
      echo -ne "\ek$(basename $(pwd))\e\\"
    fi

    psvar=()
    LANG=en_US.UTF-8 vcs_info
    [[ -n "$vcs_info_msg_0_" ]] && psvar[1]="$vcs_info_msg_0_"

    if [ "$COMMAND_TIME" -ne "0" ] ; then
      local d=`date +%s`
      d=`expr $d - $COMMAND_TIME`
      if [ "$d" -ge "10" ] ; then
        COMMAND="$COMMAND "
        growlnotify -t "${${(s: :)COMMAND}[1]}" -m "$COMMAND"
      fi
    fi
    COMMAND="0"
    COMMAND_TIME="0"
  }
  precmd_functions+=precmd_growl
fi

function preexec () {
  COMMAND="${1}"
  if [ "$TERM" = "screen" ] ; then
    echo -ne "\ek${COMMAND%% *}\e\\"
  fi
  if [ "`perl -e 'print($ARGV[0]=~/ssh|^vi|^git|^script\/(?:console|server)/)' $COMMAND`" -ne 1 ] ; then
    COMMAND_TIME=`date +%s`
  fi
}

case ${UID} in
0)
  PROMPT="%B%{${fg[red]}%}%/#%{${reset_color}%}%b "
  PROMPT2="%B%{${fg[red]}%}%_#%{${reset_color}%}%b "
  SPROMPT="%B%{${fg[red]}%}%r is correct? [n,y,a,e]:%{${reset_color}%}%b "
  [ -n "${REMOTEHOST}${SSH_CONNECTION}" ] &&
    PROMPT="%{${fg[white]}%}${HOST%%.*} ${PROMPT}"
  ;;
*)
  PROMPT="%{${fg[red]}%}%/%%%{${reset_color}%} "
  PROMPT2="%{${fg[red]}%}%_%%%{${reset_color}%} "
  SPROMPT="%{${fg[red]}%}%r is correct? [n,y,a,e]:%{${reset_color}%} "
  [ -n "${REMOTEHOST}${SSH_CONNECTION}" ] &&
    PROMPT="%{${fg[white]}%}${HOST%%.*} ${PROMPT}"
  ;;
esac

if [ -f $HOME/.zsh/zaw/zaw.zsh ]; then
  source $HOME/.zsh/zaw/zaw.zsh
  #bindkey '^G' zaw-git-files
  bindkey '^X^G' zaw-git-all-files
fi

### z.sh
if [[ -s $HOMEBREW_PREFIX/etc/profile.d/z.sh ]]; then
  _Z_CMD='j'
  source $HOMEBREW_PREFIX/etc/profile.d/z.sh
  function precmd_z () {
    _z --add "$(pwd -P)"
  }
  precmd_functions+=precmd_z
  # なぜか complete_aliases が効かないため
  #compdef _z j
fi

############################################################
# notification
# https://github.com/unasuke/dotfiles/blob/ffb45c7b13f6f255b667a6140b026a8c0eb5982f/zsh/.zsh.d/darwin.zsh
############################################################

__timetrack_threshold=5 # seconds
read -r -d '' __timetrack_ignore_progs <<EOF
less
emacs vi vim
ssh mosh telnet nc netcat
gdb
EOF

export __timetrack_threshold
export __timetrack_ignore_progs

function __my_preexec_start_timetrack() {
  local command=$1

  export __timetrack_start=`date +%s`
  export __timetrack_command="$command"
}

function __my_preexec_end_timetrack() {
  local exec_time
  local command=$__timetrack_command
  local prog=$(echo $command|awk '{print $1}')
  local notify_method
  local message

  export __timetrack_end=`date +%s`

  if test -n "${REMOTEHOST}${SSH_CONNECTION}"; then
    notify_method="remotehost"
  elif which osascript >/dev/null 2>&1; then
    notify_method="osascript"
  elif which notify-send >/dev/null 2>&1; then
    notify_method="notify-send"
  else
    return
  fi

  if [ -z "$__timetrack_start" ] || [ -z "$__timetrack_threshold" ]; then
    return
  fi

  for ignore_prog in $(echo $__timetrack_ignore_progs); do
    [ "$prog" = "$ignore_prog" ] && return
  done

  exec_time=$((__timetrack_end-__timetrack_start))
  if [ -z "$command" ]; then
    command="<UNKNOWN>"
  fi

  message="Command finished!\nTime: $exec_time seconds\nCOMMAND: $command"

  if [ "$exec_time" -ge "$__timetrack_threshold" ]; then
    case $notify_method in
      "remotehost" )
        # show trigger string
        echo -e "\e[0;30m==ZSH LONGRUN COMMAND TRACKER==$(hostname -s): $command ($exec_time seconds)\e[m"
        sleep 1
        # wait 1 sec, and then delete trigger string
        echo -e "\e[1A\e[2K"
        ;;
      "osascript" )
        # echo "$message" | growlnotify -n "ZSH timetracker" --appIcon Terminal
        #osascript -e "display notification \"$message\" with title \"zsh\""
        ;;
      "notify-send" )
        notify-send "ZSH timetracker" "$message"
        ;;
    esac
  fi

  unset __timetrack_start
  unset __timetrack_command
}

if which osascript >/dev/null 2>&1 ||
  which notify-send >/dev/null 2>&1 ||
  test -n "${REMOTEHOST}${SSH_CONNECTION}"; then
  add-zsh-hook preexec __my_preexec_start_timetrack
  add-zsh-hook precmd __my_preexec_end_timetrack
fi


# rbenv
export PATH=$HOME/.rbenv/bin:$PATH
if [ -x $HOME/.rbenv/bin/rbenv ]; then
  eval "$(rbenv init - zsh)"
fi

# awssh
export AWSSH_PERCOL=$HOMEBREW_PREFIX/bin/peco
export AWSSH_CSSH=tmux-cssh

# peco
function git-ls-peco-open() {
  local files=`git ls-files | peco`
  if [ -n "$files" ]; then
    BUFFER="vi ${files}"
    zle accept-line
  fi
}
zle -N git-ls-peco-open
bindkey '^G' git-ls-peco-open

# golang
export GOPATH=$HOME/gocode
export GOROOT=$HOMEBREW_PREFIX/opt/go/libexec
export PATH=$GOPATH/bin:$PATH

# gcutil
# https://cloud.google.com/sdk/#Quick_Start
# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then
  source "$HOME/google-cloud-sdk/path.zsh.inc"
fi
# The next line enables shell command completion for gcloud.
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

if [ -f $HOME/.zshrc.secret ]; then source $HOME/.zshrc.secret; fi
if [ -f $HOME/.zshrc.work ]; then source $HOME/.zshrc.work; fi

# Android
export ANDROID_SDK_ROOT=~/Library/Android/sdk
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
export PATH=$PATH:$ANDROID_SDK_ROOT/emulator
export PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin

# Enable startup time profiler:
# zprof
