install: ${prefix}/usr/bin/keyprotect-luks ${prefix}/usr/lib/systemd/system/keyprotect-luks.service

${prefix}/usr/bin/keyprotect-luks: keyprotect-luks
	install -m 755 -o root -g root -D keyprotect-luks -t "${prefix}/usr/bin"

${prefix}/usr/lib/systemd/system/keyprotect-luks.service: keyprotect-luks.service
	install -m 644 -o root -g root -D keyprotect-luks.service -t "${prefix}/usr/lib/systemd/system"

${prefix}/usr/share/doc/keyprotect-luks/README.md: README.md
	install -m 644 -o root -g root -D README.md -t "${prefix}/usr/share/doc/keyprotect-luks"

${prefix}/usr/share/doc/keyprotect-luks/keyprotect-luks.ini: keyprotect-luks.ini
	install -m 644 -o root -g root -D keyprotect-luks.ini -t "${prefix}/usr/share/doc/keyprotect-luks"
