#!/bin/sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# Start picom
picom -C &

#Wallpaper

# Status Bar
/home/user/dwmscripts/dwmbar &

# Set US Keyboard
setxkbmap -layout us &

# Execute DWM
exec /usr/local/bin/dwm

# Loop
while true; do
            dwm >/dev/null 2>&1
done
