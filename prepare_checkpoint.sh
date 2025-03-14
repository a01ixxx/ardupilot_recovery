#!/bin/bash

cp gps_data.txt /tmp/

tmux kill-session -t "geck_recovery_block"

# Name of the tmux session
SESSION_NAME="geck_recovery_block"

# Step 1: Create a new tmux session with the first window in detached mode
tmux new-session -d -s "$SESSION_NAME" -n "window1"

# Check if the session was created successfully
if [ $? -eq 0 ]; then
    echo "Tmux session '$SESSION_NAME' created successfully."
else
    echo "Failed to create tmux session '$SESSION_NAME'."
    exit 1
fi

tmux split-window -h -t "$SESSION_NAME:0"

# Send the commands to the tmux session
COMMANDS_WINDOW1=(
    "echo 'This is Window 1'"
    "./build/sitl/bin/arducopter --model quad --defaults=Tools/autotest/default_params/copter.parm"
)

for CMD in "${COMMANDS_WINDOW1[@]}"; do
    tmux send-keys -t "$SESSION_NAME:0.0" "$CMD" C-m
    echo "Sent command to Window 1: $CMD"
    sleep 1   # Optional delay
done

sleep 10


COMMANDS_WINDOW2=(
    "echo 'This is Window 2'"
    "mavproxy.py --master tcp:127.0.0.1:5760 --map --console"
    "mode guided"
    "wp load Tools/autotest/CMAC-circuit.txt"
)

for CMD in "${COMMANDS_WINDOW2[@]}"; do
    tmux send-keys -t "$SESSION_NAME:0.1" "$CMD" C-m
    echo "Sent command to Window 2: $CMD"
    sleep 5 
done

sleep 30

OTHER_COMMANDS_WINDOW2=(
    "arm throttle"
    "takeoff 10"
)

for CMD in "${OTHER_COMMANDS_WINDOW2[@]}"; do
    tmux send-keys -t "$SESSION_NAME:0.1" "$CMD" C-m
    echo "Sent command to Window 2: $CMD"
    sleep 5 
done

sleep 15

## Start the mission
tmux send-keys -t "$SESSION_NAME:0.1" "mode auto" C-m

sleep 30

# Kill mavproxy firste
PID=$(pgrep -f "mavproxy.py")
kill -9 $PID


# Checkpoint ardupilot
PID=$(pidof arducopter)
echo "Ardupilot task ID is:"
echo $PID
sudo ~/Gecko/checkpoint_restore/criu/criu dump -t $PID -D /tmp --shell-job

echo "Initialized version is checkpointed, then you can launch the mission."
