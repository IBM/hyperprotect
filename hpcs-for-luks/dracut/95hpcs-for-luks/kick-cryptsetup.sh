#!/bin/sh

if grep -q "rd.hpcs-for-luks" /proc/cmdline; then
	echo "initramfs: Kick cryptsetup"
	systemctl restart cryptsetup.target
	#systemctl enable remote-cryptsetup.target
	#systemctl start remote-cryptsetup.target
else
	echo "initramfs: Kick cryptsetup: rd.hpcs-for-luks not set"
fi
