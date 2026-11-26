# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
# /etc/omarchy.conf is written by omarchy-dev-link. When absent, force the
# package default instead of preserving a stale inherited dev-link value before
# we decide which rc file to source.
if [[ -f /etc/omarchy.conf ]]; then
  source /etc/omarchy.conf
  export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
else
  export OMARCHY_PATH=/usr/share/omarchy
fi
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

gph() {
  if [ -z "$*" ]; then
    echo "Usage: gph <commit message>" >&2
    return 1
  fi
  git add . && git commit -m "$*" && git push
}



# Added by Antigravity CLI installer
export PATH="/home/rustam/.local/bin:$PATH"
export LIBVA_DRIVER_NAME=i965

. "$HOME/.local/share/../bin/env"
export PATH="/opt/arm-gnu-toolchain/bin:$PATH"

# Expand process call stack to 256MB (matches Codeforces/Meta Hacker Cup, prevents false recursion segfaults)
ulimit -s 262144 2>/dev/null

export PATH=$PATH:/home/rustam/.spicetify
alias cf='cd ~/cp && nvim'
alias gtn='cd ~/.config/nvim'

# Unalias unused Omarchy defaults
unalias d r h a c cx cy ic ix icx 2>/dev/null

# Quick C++17 compile & run from terminal
cpr() {
  if [ -z "$1" ]; then echo "Usage: cpr <file.cpp>" >&2; return 1; fi
  g++ -O2 -std=c++17 -fuse-ld=mold "$1" -o /tmp/__cp_out && /tmp/__cp_out
}

cpsan() {
  if [ -z "$1" ]; then echo "Usage: cpsan <file.cpp>" >&2; return 1; fi
  g++ -O2 -std=c++17 -D_GLIBCXX_ASSERTIONS -fsanitize=address,undefined -g "$1" -o /tmp/__cp_san && /tmp/__cp_san
}
