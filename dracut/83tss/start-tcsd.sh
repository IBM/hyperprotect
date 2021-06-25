#!/bin/sh

if grep -q "rd.tss" /proc/cmdline; then
	echo "Starting tcsd in initramfs"
	/usr/sbin/tcsd
else
	echo "Dracut tss module says rd.tss is not set on the cmdline"
fi

