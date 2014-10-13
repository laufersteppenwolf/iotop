#!/bin/bash
#
# iotop similar program to capture I/O activity per process
# By laufersteppenwolf

var=""
old="\n"
new=""

if [[ !( -e /proc/self/io ) ]]; then
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

# get all PIDs
pid_all=$(ps -A -o pid | sed '/PID/d')  # ubuntu
#pid_all=$(ps | awk '{ print $2}' | sed '/PID/d')  # android

bytes2kb() {
	local var=$(expr $1 '/' 1024)
	echo $var
}

bytes2mb() {
	local var=$(expr $1 '/' 1048576)
	echo $var
}

get_old() {
	read_old=$(cat /proc/${1}/io | grep 'read_bytes:' | cut -d ' ' -f2)
	write_old=$(cat /proc/${1}/io | grep 'write_bytes:' | cut -d ' ' -f2 | head -1)
}

get_new() {
	read_new=$(cat /proc/${1}/io | grep 'read_bytes:' | cut -d ' ' -f2)
	write_new=$(cat /proc/${1}/io | grep 'write_bytes:' | cut -d ' ' -f2 | head -1)
}

for pid in ${pid_all}; do
process=""
if [[ -a /proc/${pid}/cmdline ]]; then
	process=$(cat /proc/${pid}/cmdline)
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
	process=$(cat /proc/${pid}/cmdline)
fi

if [[ -a /proc/${pid}/io && $process != "" ]]; then
get_new ${pid}
old_read=$(echo -e ${old} | grep pid:$pid | head -1 | cut -d ' ' -f3 | cut -d ':' -f2)
old_write=$(echo -e ${old} | grep pid:$pid | head -1 | cut -d ' ' -f4 | cut -d ':' -f2)
if [[ $read_new = 0 && $write_new = 0 ]]; then
	echo "Skipping process with no IO"
else
#echo "$process"
#echo "old read: $old_read"
#echo "new read: $read_new"
#echo "old write: $old_write"
#echo "new write: $write_new"

read_speed=$(expr $read_new - $old_read)
write_speed=$(expr $write_new - $old_write)

#echo "read speed: $read_speed"
#echo "write speed: $write_speed"
#echo ""
#echo "b2kb: $(bytes2kb $read_speed)"

read_speed_kb=$(bytes2kb $read_speed)
write_speed_kb=$(bytes2kb $write_speed)
read_speed_mb=$(bytes2mb $read_speed)
write_speed_mb=$(bytes2mb $write_speed)
read_new_kb=$(bytes2kb $read_new)
write_new_kb=$(bytes2kb $write_new)
read_new_mb=$(bytes2mb $read_new)
write_new_mb=$(bytes2mb $write_new)

new="$new $pid	$read_new_kb	$write_new_kb	$read_speed_kb		$write_speed_kb 		$process\n"
fi
fi
done

echo " PID	READ	WRITTEN	READ_SPEED	WRITE_SPEED	PROCESS"
echo -e "$new"

