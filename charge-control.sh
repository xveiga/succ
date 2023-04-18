#!/system/bin/sh

#### Default control parameters ####
default_params()
{
    UPPER_CHARGING_LIMIT=80
    LOWER_CHARGING_LIMIT=70
    SLEEP_DELAY=60
    ENABLE=true
    set_current 500000
}

#### Control files and permissions ####
BATTERY_PERCENTAGE_FILE="/sys/class/power_supply/battery/capacity"
CHARGE_SWITCH="/sys/class/power_supply/battery/input_suspend"
CURRENT_SWITCH="/sys/class/power_supply/battery/constant_charge_current_max"
CONTROL_PIPE="/dev/succ-pipe"

# Set write permission on charge control switches
set_permissions()
{
    chmod +w $BATTERY_PERCENTAGE_FILE
    chmod +w $CHARGE_SWITCH
    chmod +w $CURRENT_SWITCH
}


#### Charge control routines ####
set_current()
{
    echo "$1" > "$CURRENT_SWITCH"
}

charge_control()
{
    BATTERY_PERCENTAGE=$(cat $BATTERY_PERCENTAGE_FILE)
    # If battery reaches upper charging limit, and its charging, stop charging
    if [ "$BATTERY_PERCENTAGE" -ge "$UPPER_CHARGING_LIMIT" ]; then
        # Verify charge switch is not already set
        if [ "$(cat $CHARGE_SWITCH)" = "0" ]; then
            echo 1 > "$CHARGE_SWITCH"
            notify "Triggered charge stop at $BATTERY_PERCENTAGE% on $(date)"
        fi
    # If battery reaches lower charging limit, and its not charging, start charging
    elif [ "$BATTERY_PERCENTAGE" -lt "$LOWER_CHARGING_LIMIT" ]; then
        # Verify charge switch is not already set
        if [ "$(cat $CHARGE_SWITCH)" = "1" ]; then
            echo 0 > "$CHARGE_SWITCH"
            notify "Triggered charge start at $BATTERY_PERCENTAGE% on $(date)"
        fi
    fi
}


#### Control and signal magic ####

init()
{
    # Set control files permissions
    set_permissions
    default_params

    # Create FIFO to receive control commands if non existing
    [ -p "$CONTROL_PIPE" ] || mkfifo "$CONTROL_PIPE"

    # Setup signals
    trap on_exit EXIT
    trap on_sigusr1 USR1
    trap on_sigusr2 USR2
}

# Validates that the argument is a valid positive number
validate_number()
{
	case $1 in
        # Ignores empty, and any non-number strings
        ''|*[!0-9]*)
            return 0
            ;;
        *)
            return 1
            ;;
	esac
}

# Exit
on_exit()
{
    # Reset sleep
    nb_sleep_reset
    # Remove control pipe
    rm -f "$CONTROL_PIPE"
}

# SIGUSR1
on_sigusr1()
{
    nb_sleep_reset
    notify "Script reloading"
    sleep 2
    exec "$0" "$@"
}

# SIGUSR2
on_sigusr2()
{
    # Reset sleep
    nb_sleep_reset
    # Read control command from pipe
    read -r CMD < "$CONTROL_PIPE"
    # Parse and execute command
    parse_cmd "$CMD"
}

# Parse named pipe command
parse_cmd()
{
    # Split into command and argument
    ARG0="$(echo "$CMD" | cut -d' ' -f1)"
    ARG1="$(echo "$CMD" | cut -d' ' -f2)"
    # Ignore command if second argument is not a numeric value
    if [ -z "$ARG1" ] && validate_number "$ARG1"; then
        return
    fi
    # Parse command
    case "$ARG0" in
        # Upper charge limit
        upper)
            # Check value is within bounds
            if [ "$ARG1" -le 100 ] && [ "$ARG1" -ge 0 ] ; then
                # Set charging limit
                echo "upper $ARG1"
                notify "Charging stop limit set to $ARG1"
                UPPER_CHARGING_LIMIT="$ARG1"
            fi
            ;;
        # Lower charge limit
        lower)
            if [ "$ARG1" -le 100 ] && [ "$ARG1" -ge 0 ] ; then
                echo "lower $ARG1"
                notify "Charging start limit set to $ARG1"
                LOWER_CHARGING_LIMIT="$ARG1"
            fi
            ;;
        # Charge level polling delay
        setdelay)
            if [ "$ARG1" -le 86400 ] && [ "$ARG1" -ge 0 ] ; then
                echo "delay $ARG1"
                notify "Script delay set to $ARG1"
                SLEEP_DELAY="$ARG1"
            fi
            ;;
        # Re-set default boot parameters
        reset)
            echo "reset"
            default_params
            notify "Default parameters reset"
            ;;
        # Force charging, disable daemon control
        charge)
            echo "charge"
            ENABLE=false
            echo 0 > "$CHARGE_SWITCH"
            notify "Charge start forced"
            ;;
        # Force discharge, disable daemon control
        discharge)
            echo "discharge"
            ENABLE=false
            echo 1 > "$CHARGE_SWITCH"
            notify "Charge stop forced"
            ;;
        # Enable daemon control again
        enable)
            echo "enable"
            ENABLE=true
            notify "Daemon enabled"
            ;;
        # Disable daemon control again
        disable)
            echo "disable"
            ENABLE=false
            notify "Daemon disabled"
            ;;
        # Set maximum charging current
        current)
            if [ "$ARG1" -le 10000000 ] && [ "$ARG1" -ge 0 ] ; then
                set_current "$ARG1"
                notify "Charging current set to $ARG1"
                echo "current $ARG1"
            else
                echo "invalid current $ARG1"
            fi
            ;;
        # Unknown command, ignore
        *)
            notify "Invalid command sent to daemon"
            echo "invalid command"
            ;;
    esac
}

# Signal non-blocking sleep
# see https://mywiki.wooledge.org/SignalTrap#When_is_the_signal_handled.3F for more details
nb_sleep()
{
    sleep_pid=
    # As more than one "signal handler" is not allowed, we need to move this line to a separate function nb_sleep_reset
    # Every signal trap handler HAS to call nb_sleep_reset for the sleep to work properly
    sleep "$1" & sleep_pid=$!
    wait
    sleep_pid=
}

nb_sleep_reset()
{
    [[ "$sleep_pid" ]] && kill "$sleep_pid"
}

notify()
{
    su -lp 2000 -c "/system/bin/cmd notification post -S bigtext -t 'SUCC' 'SUCC' \"$1\"" > /dev/null
}

run()
{
    # Loop indefinetly
    while $ENABLE
    do
        charge_control
        nb_sleep "$SLEEP_DELAY"
    done
}

init
run