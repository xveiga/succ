#!/system/bin/sh

#COMANDO PARA RESETEAR [alias comando alias=COMMAND]:     sudo sh -c 'kill -s SIGUSR1 $(pgrep -f "sh /data/adb/service.d/charge-control.sh")'

CHARGING_STOP=75
CHARGING_START=70
SLEEP_DELAY=60
CHARGESPEED=500000 #velocidad en mA * 1000
NIGHT_TIME="2300" #Hora en formato HHMM
DAY_TIME="0530"

CURRENT_SWITCH=/sys/class/power_supply/battery/constant_charge_current_max
CHARGING_SWITCH=/sys/class/power_supply/battery/input_suspend
CHARGE_LEVEL=/sys/class/power_supply/battery/capacity

#permiso de escritura a archivos
chmod +w $CURRENT_SWITCH
chmod +w $CHARGING_SWITCH

echo $CHARGESPEED > $CURRENT_SWITCH

# Reload config when receiving SIGUSR1
trap reload_config SIGUSR1

#MAGIA DE XIAOXIAO
reload_config() 
{
    nb_sleep_reset
    exec "$0" "$@"
}

nb_sleep()
{
    sleep_pid=
    sleep "$1" & sleep_pid=$!
    wait
    sleep_pid=
}

nb_sleep_reset()
{
    [[ $sleep_pid ]] && kill "$sleep_pid"
}

while true
do
    HOUR=$(date +"%H%M")
    if [ "$HOUR" -ge $NIGHT_TIME ] || [ "$HOUR" -le $DAY_TIME ]; then
        CHARGING_START=40
        CHARGING_STOP=60
    else
        CHARGING_START=70
        CHARGING_STOP=75
    fi

    CHARGINGSTATE=$(cat /sys/class/power_supply/battery/status)
    if [ "$CHARGINGSTATE" = "Charging" ] && [ "$(cat $CHARGE_LEVEL)" -ge $CHARGING_STOP ]; then
        echo 1 > $CHARGING_SWITCH

    elif [ "$CHARGINGSTATE" = "Discharging" ] && [ "$(cat $CHARGE_LEVEL)" -le $CHARGING_START ]; then
        echo 0 > $CHARGING_SWITCH
    fi
    nb_sleep $SLEEP_DELAY
done