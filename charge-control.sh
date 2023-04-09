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
# trap reload_config 10
# reload_config()
# {
#     source $CONFIG_FILE
# }

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
    sleep $SLEEP_DELAY
done