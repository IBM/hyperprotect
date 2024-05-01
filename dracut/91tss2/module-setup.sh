#!/usr/bin/bash

__BINARIES="\
	tsscreate \
	tsscreateprimary \
	tssload \
	tsspcrread \
	tsspolicymaker \
	tsspolicymakerpcr \
	tsspolicypcr \
	tssstartauthsession \
	tssunseal \
	"

__LIBRARIES="\
	'libibmtss.so.*' \
	'libibmtssutils.so.*'\
	"

check() {
	require_binaries ${__BINARIES} || return 1
	return 255
}

depends() {
	echo systemd-sysusers systemd-udevd
	return 0
}

installkernel() {
	instmods '=drivers/char/tpm'
}

install() {
	inst_multiple -o $udevrulesdir/60-tpm-udev.rules ${__BINARIES}
	inst_libdir_file ${__LIBRARIES}
	inst_simple "$moddir/tss2-seal.sh" /usr/bin/tss2-seal.sh
	inst_simple "$moddir/tss2-unseal.sh" /usr/bin/tss2-unseal.sh
	inst_simple "$moddir/tss2-unseal-to-keyring.sh" /usr/bin/tss2-unseal-to-keyring.sh
}
