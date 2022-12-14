#!/bin/sh

cmd="$1"

. /scripts/functions

daemon="telnetd"

# launch a shell on telnet connect
ARGS="-l /bin/onie-console -f /etc/issue.null"

case $cmd in
    start)
        killall $daemon > /dev/null 2>&1
        log_begin_msg "Starting: $daemon"
        cd / && $daemon $ARGS
        log_end_msg
        ;;
    stop)
        log_begin_msg "Stopping: $daemon"
        killall $daemon > /dev/null 2>&1
        log_end_msg
        ;;
    *)
        
esac

