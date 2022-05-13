#!/bin/sh

if grep -q "rd.tss" /proc/cmdline; then
	echo "Stopping tcsd in initramfs"
	kill `ps -C tcsd -opid --no-headers`
	echo $?
else
	echo "Dracut tss module says rd.tss is not set on the cmdline"
fi

