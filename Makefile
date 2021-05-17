install: $(DESTDIR)/usr/bin/keyprotect-luks \
	 $(DESTDIR)/usr/lib/systemd/system/keyprotect-luks.service \
	 $(DESTDIR)/usr/share/doc/keyprotect-luks/README.md \
	 $(DESTDIR)/usr/share/doc/keyprotect-luks/keyprotect-luks.ini \
	 $(DESTDIR)/var/lib/keyprotect-luks \
	 $(DESTDIR)/var/lib/keyprotect-luks/logon \
	 $(DESTDIR)/var/lib/keyprotect-luks/user

$(DESTDIR)/usr/bin/keyprotect-luks: keyprotect-luks
	install -m 755 -D keyprotect-luks -t "$(DESTDIR)/usr/bin"

$(DESTDIR)/usr/lib/systemd/system/keyprotect-luks.service: keyprotect-luks.service
	install -m 644 -D keyprotect-luks.service -t "$(DESTDIR)/usr/lib/systemd/system"

$(DESTDIR)/usr/share/doc/keyprotect-luks/README.md: README.md
	install -m 644 -D README.md -t "$(DESTDIR)/usr/share/doc/keyprotect-luks"

$(DESTDIR)/usr/share/doc/keyprotect-luks/keyprotect-luks.ini: keyprotect-luks.ini
	install -m 644 -D keyprotect-luks.ini -t "$(DESTDIR)/usr/share/doc/keyprotect-luks"

$(DESTDIR)/var/lib/keyprotect-luks:
	install -m 755 -d $(DESTDIR)/var/lib/keyprotect-luks

$(DESTDIR)/var/lib/keyprotect-luks/logon:
	install -m 755 -d $(DESTDIR)/var/lib/keyprotect-luks/logon

$(DESTDIR)/var/lib/keyprotect-luks/user:
	install -m 755 -d $(DESTDIR)/var/lib/keyprotect-luks/user
