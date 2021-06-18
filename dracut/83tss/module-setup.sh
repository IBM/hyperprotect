#!/bin/bash

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
	inst_hook pre-mount 10 "$moddir/start-tcsd.sh"
	inst_simple start-tcsd.sh "$moddir/start-tcsd.sh"
	inst_simple /usr/sbin/tcsd
	inst_simple /usr/bin/tpm_unsealdata
	inst_simple /usr/sbin/tpm_version
	echo 'tss:x:59:59:Account used for TPM access:/dev/null:/sbin/nologin' >> "$initdir/etc/passwd"
	echo 'tss:x:59:' >> "$initdir/etc/group"
	inst_simple /var/lib/keyprotect-luks/api-key-blob.txt
	inst_hook cleanup 10 "$moddir/stop-tcsd.sh"
}
