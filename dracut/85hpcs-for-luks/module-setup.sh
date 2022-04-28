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
	inst_hook initqueue/online 20 "${moddir}/${_UTILITY_NAME}.sh"
	inst_simple ${_UTILITY_NAME}.sh "${moddir}/${_UTILITY_NAME}.sh"
	inst_simple /etc/${_UTILITY_NAME}.ini
	inst_simple /var/lib/${_UTILITY_NAME}/user/luks:root
	inst_simple /usr/bin/base64
	inst_simple /lib64/libkeyutils.so.1
	inst_simple /usr/bin/keyctl
}
