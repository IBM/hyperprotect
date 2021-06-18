#!/bin/sh

if grep -q "rd.tss" /proc/cmdline; then
	echo "Starting tcsd in initramfs"
	/usr/sbin/tcsd
	sleep 1
	tpm_version
	tpm_unsealdata -i /var/lib/keyprotect-luks/api-key-blob.txta -z
else
	echo "Dracut tss module says rd.tss is not set on the cmdline"
fi

