#!/bin/sh

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# Start picom
picom -C -mark-ovredir-focused &

#Wallpaper

# Status Bar

# Set US Keyboard
setxkbmap -layout us &

# Execute i3
exec i3
