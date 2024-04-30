#!/bin/bash

_UTILITY_NAME=hpcs-for-luks

# called by dracut
check() {
	# Don't include this module by default.
	return 255
}

# called by dracut
depends() {
	require_binaries /usr/sbin/tcsd /usr/bin/tpm_unsealdata || return 1
	return 0
}

# called by dracut
install() {
	inst_hook initqueue/online 10 "$moddir/start-tcsd.sh"
	inst_simple start-tcsd.sh "$moddir/start-tcsd.sh"
	inst_simple /usr/sbin/tcsd
	inst_simple /var/lib/tpm/system.data
	echo 'tss:x:59:59:Account used for TPM access:/dev/null:/sbin/nologin' >> "$initdir/etc/passwd"
	echo 'tss:x:59:' >> "$initdir/etc/group"
	inst_simple /usr/bin/tpm_unsealdata
	inst_simple /var/lib/${_UTILITY_NAME}/api-key-blob.txt
	inst_hook initqueue/online 15 "$moddir/run-tss-cmds.sh"
	inst_simple run-tss-cmds.sh "$moddir/run-tss-cmds.sh"
	inst_hook cleanup 10 "$moddir/stop-tcsd.sh"
}
