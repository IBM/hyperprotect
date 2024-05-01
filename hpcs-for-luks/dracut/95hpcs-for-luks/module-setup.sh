#!/bin/bash

_UTILITY_NAME="hpcs-for-luks"

# called by dracut
check() {
	# Don't include this module by default.
	return 255
} 

# called by dracut
depends() {
	require_binaries /usr/bin/base64 /usr/bin/keyctl || return 1
	return 0
}

# called by dracut
install() {
	# Handle cryptsetup's tmp file, otherwise it will complain
	inst_simple "$moddir/cryptsetup-tmpfiles.conf" /usr/lib/tmpfiles.d/cryptsetup-tmpfiles.conf

	# Different service than in real root 
	inst_simple "$moddir/${_UTILITY_NAME}-dracut.service" "$systemdsystemunitdir/${_UTILITY_NAME}-dracut.service"
	# Enable service in the initramfs image
	$SYSTEMCTL -q --root "$initdir" enable ${_UTILITY_NAME}-dracut.service

	# This shell script is not the the same Python program in ordinary userspace
	inst_simple "$moddir/${_UTILITY_NAME}-dracut.sh" /usr/bin/${_UTILITY_NAME}-dracut.sh
	# Same ini file as in real root
	inst_simple /etc/${_UTILITY_NAME}.ini
	# Root volume wrapped LUKS passphrase file
	inst_simple /var/lib/${_UTILITY_NAME}/user/luks:root

	# Need to decode authentication response
	inst_simple /usr/bin/base64

	# keyctl support
	inst_simple /lib64/libkeyutils.so.1
	inst_simple /usr/bin/keyctl

	dracut_need_initqueue
}
