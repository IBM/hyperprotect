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
	inst_simple "$moddir/${_UTILITY_NAME}-dracut.service" /usr/lib/systemd/system/${_UTILITY_NAME}-dracut.service
	# Enable services in the initramfs image
	systemctl -q --root "$initdir" enable ${_UTILITY_NAME}-dracut.service
	systemctl -q --root "$initdir" enable remote-cryptsetup.target
	# This shell script is not the the same Python program in ordinary userspace
	inst_simple "$moddir/${_UTILITY_NAME}-dracut.sh" /usr/bin/${_UTILITY_NAME}-dracut.sh
	#inst_hook pre-trigger 99 "$moddir/${_UTILITY_NAME}.sh"
	#inst_hook initqueue/online 20 "$moddir/${_UTILITY_NAME}.sh"
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
	inst_simple "$moddir/shelldrop.sh" /usr/bin/shelldrop.sh
	# Fixup crypttab
	awk '{ NEWOPT=""; if ($4 != "") NEWOPT = ","; NEWOPT = $4NEWOPT"_netdev,timeout=1"; print $1 $2 $3 NEWOPT}' <${initdir}/etc/crypttab >${initdir}/etc/crypttab.new; mv ${initdir}/etc/crypttab.new ${initdir}/etc/crypttab
	dracut_need_initqueue
}
