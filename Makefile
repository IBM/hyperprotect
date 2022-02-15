rpm:
	rm -f keyprotect-luks-1.0.tar.gz
	tar --xform='s/^/keyprotect-luks-1.0\//' -cpzf keyprotect-luks-1.0.tar.gz *
	cp -p keyprotect-luks-1.0.tar.gz ~/rpmbuild/SOURCES
	cp -p keyprotect-luks.spec ~/rpmbuild/SPECS
	rpmbuild -ba ~/rpmbuild/SPECS/keyprotect-luks.spec


install: \
	$(DESTDIR)/usr/bin/keyprotect-luks \
	$(DESTDIR)/usr/lib/systemd/system/keyprotect-luks.service \
	$(DESTDIR)/usr/share/doc/keyprotect-luks/README.md \
	$(DESTDIR)/usr/share/doc/keyprotect-luks/keyprotect-luks.ini \
	$(DESTDIR)/usr/share/man/man1/keyprotect-luks.1.gz \
	$(DESTDIR)/var/lib/keyprotect-luks \
	$(DESTDIR)/var/lib/keyprotect-luks/logon \
	$(DESTDIR)/var/lib/keyprotect-luks/user

install-dracut: \
	$(DESTDIR)/usr/lib/dracut/modules.d/85keyprotect-luks \
	$(DESTDIR)/usr/lib/dracut/modules.d/85keyprotect-luks/keyprotect-luks.sh \
	$(DESTDIR)/usr/lib/dracut/modules.d/85keyprotect-luks/module-setup.sh \
	$(DESTDIR)/etc/dracut.conf.d/keyprotect-luks.conf \
	$(DESTDIR)/usr/lib/dracut/modules.d/83tss \
	$(DESTDIR)/usr/lib/dracut/modules.d/83tss/module-setup.sh \
	$(DESTDIR)/usr/lib/dracut/modules.d/83tss/start-tcsd.sh \
	$(DESTDIR)/usr/lib/dracut/modules.d/83tss/stop-tcsd.sh \
	$(DESTDIR)/usr/lib/dracut/modules.d/83tss/run-tss-cmds.sh \
	$(DESTDIR)/etc/dracut.conf.d/tss.conf

$(DESTDIR)/usr/bin/keyprotect-luks: keyprotect-luks
	install -m 755 -D keyprotect-luks -t "$(DESTDIR)/usr/bin"

$(DESTDIR)/usr/lib/systemd/system/keyprotect-luks.service: keyprotect-luks.service
	install -m 644 -D keyprotect-luks.service -t "$(DESTDIR)/usr/lib/systemd/system"

$(DESTDIR)/usr/share/doc/keyprotect-luks/README.md: README.md
	install -m 644 -D README.md -t "$(DESTDIR)/usr/share/doc/keyprotect-luks"

$(DESTDIR)/usr/share/doc/keyprotect-luks/keyprotect-luks.ini: keyprotect-luks.ini
	install -m 644 -D keyprotect-luks.ini -t "$(DESTDIR)/usr/share/doc/keyprotect-luks"

$(DESTDIR)/usr/share/man/man1/keyprotect-luks.1.gz: keyprotect-luks.1
	mkdir -p "$(DESTDIR)/usr/share/man/man1"
	gzip <keyprotect-luks.1 >"$(DESTDIR)/usr/share/man/man1/keyprotect-luks.1.gz"
	chmod 644 "$(DESTDIR)/usr/share/man/man1/keyprotect-luks.1.gz"

$(DESTDIR)/var/lib/keyprotect-luks:
	install -m 755 -d $(DESTDIR)/var/lib/keyprotect-luks

$(DESTDIR)/var/lib/keyprotect-luks/logon:
	install -m 755 -d $(DESTDIR)/var/lib/keyprotect-luks/logon

$(DESTDIR)/var/lib/keyprotect-luks/user:
	install -m 755 -d $(DESTDIR)/var/lib/keyprotect-luks/user

$(DESTDIR)/usr/lib/dracut/modules.d/85keyprotect-luks:
	install -m 755 -d $(DESTDIR)/usr/lib/dracut/modules.d/85keyprotect-luks

$(DESTDIR)/usr/lib/dracut/modules.d/85keyprotect-luks/keyprotect-luks.sh: dracut/85keyprotect-luks/keyprotect-luks.sh
	install -m 755 -D dracut/85keyprotect-luks/keyprotect-luks.sh -t "$(DESTDIR)/usr/lib/dracut/modules.d/85keyprotect-luks"

$(DESTDIR)/usr/lib/dracut/modules.d/85keyprotect-luks/module-setup.sh: dracut/85keyprotect-luks/module-setup.sh
	install -m 755 -D dracut/85keyprotect-luks/module-setup.sh -t "$(DESTDIR)/usr/lib/dracut/modules.d/85keyprotect-luks"

$(DESTDIR)/etc/dracut.conf.d/keyprotect-luks.conf: dracut/keyprotect-luks.conf
	install -m 644 -D dracut/keyprotect-luks.conf -t "$(DESTDIR)/etc/dracut.conf.d"

$(DESTDIR)/usr/lib/dracut/modules.d/83tss:
	install -m 755 -d $(DESTDIR)/usr/lib/dracut/modules.d/83tss

$(DESTDIR)/usr/lib/dracut/modules.d/83tss/module-setup.sh: dracut/83tss/module-setup.sh
	install -m 755 -D dracut/83tss/module-setup.sh -t "$(DESTDIR)/usr/lib/dracut/modules.d/83tss"

$(DESTDIR)/usr/lib/dracut/modules.d/83tss/start-tcsd.sh: dracut/83tss/start-tcsd.sh
	install -m 755 -D dracut/83tss/start-tcsd.sh -t "$(DESTDIR)/usr/lib/dracut/modules.d/83tss"

$(DESTDIR)/usr/lib/dracut/modules.d/83tss/stop-tcsd.sh: dracut/83tss/stop-tcsd.sh
	install -m 755 -D dracut/83tss/stop-tcsd.sh -t "$(DESTDIR)/usr/lib/dracut/modules.d/83tss"

$(DESTDIR)/usr/lib/dracut/modules.d/83tss/run-tss-cmds.sh: dracut/83tss/run-tss-cmds.sh
	install -m 755 -D dracut/83tss/run-tss-cmds.sh -t "$(DESTDIR)/usr/lib/dracut/modules.d/83tss"

$(DESTDIR)/etc/dracut.conf.d/tss.conf: dracut/tss.conf
	install -m 644 -D dracut/tss.conf -t "$(DESTDIR)/etc/dracut.conf.d"

