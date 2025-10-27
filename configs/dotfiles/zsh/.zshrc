
# ==========================================
# Zsh configuration optimized for developers
# ==========================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(git zoxide fzf golang rust python)

source $ZSH/oh-my-zsh.sh
source ~/.config/zsh/aliases.zsh

# Developer environment
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin:/usr/local/go/bin
eval "$(zoxide init zsh)"
