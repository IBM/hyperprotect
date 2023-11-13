#!/bin/bash

_UTILITY_NAME="hpcs-for-luks"

# called by dracut
check() {
    return 0
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
	# Handle cryptsetup's tmp file, otherwise it will complain
	inst_simple "$moddir/cryptsetup-tmpfiles.conf" /usr/lib/tmpfiles.d/cryptsetup-tmpfiles.conf
	# Different service than in real root 
	inst_simple "$moddir/${_UTILITY_NAME}-dracut.service" "$systemdsystemunitdir/${_UTILITY_NAME}-dracut.service"
	# Enable services in the initramfs image
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
	# Shell to drop into a shel
	#inst_simple "$moddir/shelldrop.sh" /usr/bin/shelldrop.sh
	dracut_need_initqueue
}
