install: ${prefix}/usr/bin/keyprotect-luks ${prefix}/usr/lib/systemd/system/keyprotect-luks.service

${prefix}/usr/bin/keyprotect-luks: keyprotect-luks
	install -m 755 -o root -g root -D keyprotect-luks -t "${prefix}/usr/bin"

${prefix}/usr/lib/systemd/system/keyprotect-luks.service: keyprotect-luks.service
	install -m 644 -o root -g root -D keyprotect-luks.service -t "${prefix}/usr/lib/systemd/system"
