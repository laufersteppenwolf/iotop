#!/system/bin/sh
#
# iotop similar program to capture I/O activity per process
# By laufersteppenwolf@xda

show_help() {
cat << EOL

Usage: ./iotop.sh [-h -m -b --show_skips]

Show the I/O usage on per-app/per-process basis.
READ and WRITTEN show the total amount of bytes read or written
to the storage per process.
READ_SPEED and WRITE_SPEED show the current read and write speeds.

Default behavior is to show all units in kb.

    -h   | --help           Display this help and exit
    -m   | --mb             Change units to MB
    -b   | --bytes          Change units to bytes
    --show_skips            Print a message when skipping a process
                             with no I/O activity
    --only                  Skip processes with no I/O activity


Please note that this script is still in an early stage, which is
why it does not yet support all features iotop for PCs has.
If you want to contribute, feel free to fork the repo and issue
a pull request.

EOL
}

# reset variables just in case...
var=""
old="\n"
new=""
unit=""
read_old=0
write_old=0
read_new=0
write_new=0
old_read=0
old_write=0
only=0
show_skip=0

if [[ ! -e /proc/self/io ]]; then
    echo "Your kernel does not support I/O accounting,"
    echo "which is required for this tool to work :("
    echo ""
    echo "Please recompile your kernel with I/O accounting enabled"
    echo "or politely ask your kernel dev to enable it."
    echo ""
    echo "To enable I/O accounting the following configs have to be set:"
    echo "CONFIG_TASKSTATS"
    echo "CONFIG_TASK_IO_ACCOUNTING"
    echo "CONFIG_TASK_XACCT"
    echo "CONFIG_TASK_DELAY_ACCT"
    echo ""
    exit 1
fi


while :
do
    case $1 in
        -h | --help)
            show_help
            help=1
            exit 0
            ;;
        -m | --mb)
            unit="mb"
            shift
            ;;
        -b | --bytes)
            unit="bytes"
            shift
            ;;
        --only)
            only="1"
            shift
            ;;
        --show_skips | --show-skips)
            show_skip="1"
            shift
            ;;
        --) # End of all options
            shift
            break
            ;;
        *)  # no more options. Stop while loop
            break
            ;;	
    esac
done


# get all PIDs
#pid_all="$(ps -A -o pid | sed '/PID/d')"  # ubuntu
pid_all=$(ps | awk '{ print $2}' | sed '/PID/d')  # android

bytes2kb() {
    local var="$(expr $1 '/' 1024)"
    echo "$var"
}

bytes2mb() {
    local var="$(expr $1 '/' 1048576)"
    echo "$var"
}

get_old() {
    read_old="$(cat /proc/${1}/io | grep 'read_bytes:' | cut -d ' ' -f2)"
    write_old="$(cat /proc/${1}/io | grep 'write_bytes:' | cut -d ' ' -f2 | head -1)"
}

get_new() {
    read_new="$(cat /proc/${1}/io | grep 'read_bytes:' | cut -d ' ' -f2)"
    write_new="$(cat /proc/${1}/io | grep 'write_bytes:' | cut -d ' ' -f2 | head -1)"
}

for pid in ${pid_all}; do
    process=""
    if [[ -a /proc/${pid}/cmdline ]]; then
        process="$(cat /proc/${pid}/cmdline)"
    fi

    if [[ -a /proc/${pid}/io && $process != "" ]]; then
        get_old ${pid}
        old="$old pid:$pid read:$read_old write:$write_old\n"
        #echo -e $old
    fi
done

sleep 1

#echo -e "$old"

for pid in ${pid_all}; do
    process=""
    if [[ -a /proc/${pid}/cmdline ]]; then
        process="$(cat /proc/${pid}/cmdline)"
    fi

    if [[ -a /proc/${pid}/io && $process != "" ]]; then
        get_new "${pid}"
        old_read="$(echo -e ${old} | grep pid:$pid | head -1 | cut -d ' ' -f3 | cut -d ':' -f2)"
        old_write="$(echo -e ${old} | grep pid:$pid | head -1 | cut -d ' ' -f4 | cut -d ':' -f2)"
        if [[ $read_new = 0 && $write_new = 0 && $only = 1 ]]; then
            if [[ $show_skip = 1 ]]; then
                echo "Skipping process with no IO"
            fi
        else
            #echo "$process"
            #echo "old read: $old_read"
            #echo "new read: $read_new"
            #echo "old write: $old_write"
            #echo "new write: $write_new"

            read_speed="$(expr $read_new - $old_read)"
            write_speed="$(expr $write_new - $old_write)"

            #echo "read speed: $read_speed"
            #echo "write speed: $write_speed"
            #echo ""
            #echo "b2kb: $(bytes2kb $read_speed)"

            read_speed_kb="$(bytes2kb $read_speed)"
            write_speed_kb="$(bytes2kb $write_speed)"
            read_speed_mb="$(bytes2mb $read_speed)"
            write_speed_mb="$(bytes2mb $write_speed)"
            read_new_kb="$(bytes2kb $read_new)"
            write_new_kb="$(bytes2kb $write_new)"
            read_new_mb="$(bytes2mb $read_new)"
            write_new_mb="$(bytes2mb $write_new)"

            if [[ $unit = "mb" ]]; then
                read_new_out="$read_new_mb"
                write_new_out="$write_new_mb"
                read_speed_out="$read_speed_mb"
                write_speed_out="$write_speed_mb"
            elif [[ $unit = "bytes" ]]; then
                read_new_out="$read_new"
                write_new_out="$write_new"
                read_speed_out="$read_speed"
                write_speed_out="$write_speed"
            else
                read_new_out="$read_new_kb"
                write_new_out="$write_new_kb"
                read_speed_out="$read_speed_kb"
                write_speed_out="$write_speed_kb"
            fi


            new="$new $pid		$read_new_out		$write_new_out		$read_speed_out			$write_speed_out 			$process\n"
        fi
    fi
done

echo " PID		READ		WRITTEN		READ_SPEED		WRITE_SPEED		PROCESS"
echo -e "$new"

