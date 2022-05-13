#!/bin/sh

if grep -q "rd.hpcs-for-luks" /proc/cmdline; then
	echo "initramfs: Shell drop"
	/bin/bash -i
else
	echo "initramfs: Shell drop: rd.hpcs-for-luks not set"
fi
