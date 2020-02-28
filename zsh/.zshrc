VIM_PREFIX=/usr
if [ -d /opt/brew ]; then
  HOMEBREW_PREFIX=/opt/brew
else
  HOMEBREW_PREFIX=/usr/local
fi
export LANG=ja_JP.UTF-8
export EDITOR=$VIM_PREFIX/bin/vim
export PATH=$HOMEBREW_PREFIX/bin:$PATH
export PATH=/usr/local/bin:/opt/local/bin:$PATH
export LESS='-R'

############################################################
# aliases
############################################################
setopt complete_aliases
alias vi='vim'
alias ls='ls -lahFG'
alias where='command -v'
alias du='du -h'
alias df='df -h'
alias vz='vim ~/.zshrc; . ~/.zshrc'
alias vs='vim ~/.ssh/config'
alias vv='vim ~/.vimrc'
alias vvp='vim ~/.vimrc.plugins'
alias vh='sudo vim /etc/hosts && dscacheutil -flushcache'
function gf() { git submodule foreach git --no-pager $*; git --no-pager $* }
alias st='gf status'
alias br='gf branch'
alias co='git checkout'
alias gg='gf grep -n -E'
alias gls='git ls-files'
alias gp='git pull --rebase origin master'
alias gpp='git pull --rebase origin master && git push origin master'
alias tmux-chdir-here="pwd | xargs tmux set -g default-path"
alias tmux-copy-buffer="tmux show-buffer | pbcopy"
alias cds='cd $HOME/src'
alias cdsc='cd $HOME/scratch'
alias be='bundle exec'
alias bc='bundle console'
alias bo='bundle open'
alias ppd='git pull --rebase origin master && git push origin master && sleep 5 && bundle exec cap puppet deploy'
alias c='tmux-cssh'
alias i='i2cssh'
alias a='$HOME/src/awssh/exe/awssh'
alias gl='git ls-files'
alias zbx='envchain zabbix zabbix_graph'
alias icap='envchain gpg bundle exec cap'
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
RPROMPT="%1(v|%F{green}%1v%f|) %F{blue}[%*]%f"

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
if [[ -s `brew --prefix`/etc/profile.d/z.sh ]]; then
  _Z_CMD='j'
  source `brew --prefix`/etc/profile.d/z.sh
  function precmd_z () {
    _z --add "$(pwd -P)"
  }
  precmd_functions+=precmd_z
  # なぜか complete_aliases が効かないため
  #compdef _z j
fi

# rbenv
export PATH=$HOME/.rbenv/bin:$PATH
eval "$(rbenv init - zsh)"

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

if [ -f $HOME/.zshrc.secret ]; then source $HOME/.zshrc.secret; fi
if [ -f $HOME/.zshrc.work ]; then source $HOME/.zshrc.work; fi

