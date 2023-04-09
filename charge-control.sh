#!/system/bin/sh

# Control parameters
UPPER_CHARGING_LIMIT=80
LOWER_CHARGING_LIMIT=70
SLEEP_DELAY=60
ENABLE=true

# Control files
CONFIG_FILE="/data/adb/charge-control.prop"
BATTERY_PERCENTAGE_FILE="/sys/class/power_supply/battery/capacity"
CHARGE_SWITCH="/sys/class/power_supply/battery/input_suspend"
CURRENT_SWITCH="/sys/class/power_supply/battery/constant_charge_current_max"

# Set permissions of control files
chmod +w $BATTERY_PERCENTAGE_FILE
chmod +w $CHARGE_SWITCH
chmod +w $CURRENT_SWITCH

# Reload config when receiving SIGUSR1
trap reload_config SIGUSR1

reload_config()
{
    nb_sleep_reset
    exec "$0" "$@"
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
    [[ $sleep_pid ]] && kill "$sleep_pid"
}

# Loop indefinetly
while $ENABLE
do
    # If battery reaches upper charging limit, and its charging, stop charging
    if [ $BATTERY_PERCENTAGE_FILE -ge $UPPER_CHARGING_LIMIT ]; then
        if [ $(cat $CHARGE_SWITCH) == "0" ]; then
            echo 1 > $CHARGE_SWITCH
        fi
    # If battery reaches lower charging limit, and its not charging, start charging
    elif [ $BATTERY_PERCENTAGE_FILE -lt $LOWER_CHARGING_LIMIT ]; then
        if [ $(cat $CHARGE_SWITCH) == "1" ]; then
            echo 0 > $CHARGE_SWITCH
        fi
    fi
    nb_sleep $SLEEP_DELAY
done