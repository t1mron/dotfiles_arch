[[ $- != *i* ]] && return
[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx &> /dev/null

if [ "$TERM" = xterm ]; then
    TERM=xterm-256color;
fi

export TERM=xterm-256color

powerline-daemon -q
POWERLINE_BASH_CONTINUATION=1
POWERLINE_BASH_SELECT=1
. /usr/share/powerline/bindings/bash/powerline.sh

alias ls='lsd'
