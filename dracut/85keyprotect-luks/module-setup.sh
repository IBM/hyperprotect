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
	inst_hook pre-mount 20 "$moddir/keyprotect-luks.sh"
	inst_simple keyprotect-luks.sh "$moddir/keyprotect-luks.sh"
	inst_simple /etc/keyprotect-luks.ini
	inst_simple /var/lib/keyprotect-luks/user/luks:root
}
