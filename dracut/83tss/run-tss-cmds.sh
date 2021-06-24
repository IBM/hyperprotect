#!/bin/sh

if grep -q "rd.tss" /proc/cmdline; then
	echo "Running tss commands in initramfs"
	_API_KEY=`tpm_unsealdata -i /var/lib/keyprotect-luks/api-key-blob.txt -z`
	tpm_unsealdata -i /var/lib/keyprotect-luks/api-key-blob.txt -z
	if [ $? -eq 0 ]; then
		echo "API Key ---> $_API_KEY"
	else
		echo "tpm_unsealdata FAILED!"
	fi
else
	echo "Dracut tss module says rd.tss is not set on the cmdline"
fi

