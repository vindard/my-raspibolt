#!/bin/bash

# Source: https://michaelwelford.com/post/saving-time-preset-tmux-setup
# Note that this assumes base index of 1

# check for existence of required things
# $1 is the name of the window

if [ $# -eq 0 ]
  then
    echo "No arguments supplied, requires name of window."
    exit 1
fi

CWD=$(pwd)
SESSION_NAME="$1"

# detach from a tmux session if in one
tmux detach > /dev/null

# Create a new session, -d means detached itself
set -- $(stty size) # $1 = rows $2 = columns
tmux new-session -d -s $SESSION_NAME -x "$2" -y "$(($1 - 1))"

## Main Window
tmux select-window -t $SESSION_NAME:0
tmux rename-window 'bitcoin'

# Split into left and right
tmux split-window -h -p50

# Right ready for taking commands

# Top window: htop
tmux select-pane -t 1
tmux send-keys "htop" C-m

# Bottom window: bitcoin logs
tmux split-window -p 65
tmux send-keys "tail -n 200 -f .bitcoin/debug.log" C-m

# Middle window: temperature
tmux split-window -b -l 3
tmux send-keys "watch -n 1 vcgencmd measure_temp" C-m


# Left for lnd & terminal
tmux select-pane -t 0
tmux send-keys "sudo journalctl -fu lnd" C-m

tmux split-window -p 35


# Finally attach to it
tmux attach -t $SESSION_NAME

