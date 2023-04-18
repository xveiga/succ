#!/system/bin/sh

CONTROL_PIPE="/dev/succ-pipe"
DAEMON_PATH="/data/adb/service.d/charge-control.sh"
DAEMON_PID=$(pgrep -f "$DAEMON_PATH")

if [ "$(id -u)" != 0 ] ; then
    echo "This script needs root access"
    exit
fi

if [ -z "$DAEMON_PID" ]; then
    echo "The battery daemon is not running. May be fixed by restarting your device"
    exit
fi

validate_number()
{
    case $1 in
        ''|*[!0-9]*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

send_command()
{
	echo "$@" > "$CONTROL_PIPE" &
	kill -s USR2 "$DAEMON_PID"
}

if [ $# -le 0 ] || [ $# -ge 3 ] ; then
	echo "Wrong arguments. Usage: $0 <command> <numeric value>"
	exit 1
elif [ $# -eq 2 ] && validate_number "$2" ; then
	echo "$2 is not a valid number"
	exit 1
fi

send_command "$@"
