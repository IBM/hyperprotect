COUNTFILE=${HOME}/.ibm-keyprotect-luks-key-count
BATCHFILE=${HOME}/.ibm-keyprotect-luks-batchfile
STATFILE=${HOME}/.ibm-keyprotect-luks-statfile
BASE_KEYNAME=ibm-keyprotect-luks-build-
BASE_SIGNFILE=${HOME}/.${BASE_KEYNAME}
RPMROOT=${HOME}/rpm-user

.PHONY: clean pre-dist dist incr_gen_key sign rpm install install-dracut

clean:
	rm -f keyprotect-luks-1.0.tar.gz
	rm -f keyprotect-luks-1.0-1.el8.noarch.rpm
	rm -f SHA256SUMS

dist: pre-dist sign

pre-dist: rpm
	cp -p ~/rpmbuild/RPMS/noarch/keyprotect-luks-1.0-1.el8.noarch.rpm .
	sha256sum keyprotect-luks-1.0-1.el8.noarch.rpm > SHA256SUMS

incr_gen_key:
	if [ ! -f ${COUNTFILE} ]; then \
		KEYCOUNT=0; \
	else \
	        KEYCOUNT=`cat ${COUNTFILE}`; \
	       	KEYCOUNT=$$((KEYCOUNT+1)); \
	fi; \
	echo "Key count = $${KEYCOUNT}" 1>&2; \
	echo $${KEYCOUNT} > ${COUNTFILE}; \
	\
	PASSPHRASE=$$(dd status=none if=/dev/random bs=1 count=32 | hexdump -e '4/8 "%016x" "\n"'); \
	echo $${PASSPHRASE} > ${BASE_SIGNFILE}passphrase-$${KEYCOUNT}; \
	\
	echo "%echo Generating a GPG signing key for the keyprotect-luks package . . . "  > ${BATCHFILE}; \
	echo "Key-Type: RSA" >> ${BATCHFILE}; \
	echo "Key-Length: 2048" >> ${BATCHFILE}; \
	echo "Subkey-Type: RSA" >> ${BATCHFILE}; \
	echo "Subkey-Length: 2048" >> ${BATCHFILE}; \
	echo "Name-Real: ${BASE_KEYNAME}$${KEYCOUNT}" >> ${BATCHFILE}; \
	echo "Name-Comment: IBM Key Protect LUKS Integration RPM Signing Key" >> ${BATCHFILE}; \
	echo "Name-Email: gcwilson@us.ibm.com" >> ${BATCHFILE}; \
	echo "Expire-Date: 0" >> ${BATCHFILE}; \
	echo "Passphrase: $${PASSPHRASE}" >> ${BATCHFILE}; \
	echo "%commit" >> ${BATCHFILE}; \
	echo "%echo done" >> ${BATCHFILE}; \
	gpg2 --status-file=${STATFILE} --gen-key --pinentry-mode=loopback --batch --with-colons < ${BATCHFILE} 1>&2; \
	rm -f ${BATCHFILE}; \
	cat ${STATFILE}; 1>&2 \
	rm -f ${STATFILE}; \
	gpg --export -a ${BASE_KEYNAME}$${KEYCOUNT} > ${BASE_SIGNFILE}$${KEYCOUNT}; \
	rpm --root ${RPMROOT} --import ${BASE_SIGNFILE}$${KEYCOUNT};

sign:
	if [ ! -f ${COUNTFILE} ]; then \
		KEYCOUNT=0; \
	else \
	        KEYCOUNT=`cat ${COUNTFILE}`; \
	fi; \
	rpm --define "%_gpg_name ${BASE_KEYNAME}$${KEYCOUNT}" \
	    --define "%__gpg_sign_cmd %{__gpg} --force-v3-sigs \
	                                     --batch \
					     --verbose \
					     --no-armor \
					     --passphrase-file=${BASE_SIGNFILE}passphrase-$${KEYCOUNT} \
					     --pinentry-mode=loopback \
					     --no-secmem-warning \
					     -u \"%{_gpg_name}\" \
					     -sbo %{__signature_filename} \
					     --digest-algo sha256 \
					     %{__plaintext_filename}" \
	  --addsign keyprotect-luks-1.0-1.el8.noarch.rpm

rpm:
	rm -f keyprotect-luks-1.0.tar.gz
	tar --xform='s/^/keyprotect-luks-1.0\//' -cpzf keyprotect-luks-1.0.tar.gz *
	cp -p keyprotect-luks-1.0.tar.gz ~/rpmbuild/SOURCES
	cp -p keyprotect-luks.spec ~/rpmbuild/SPECS
	rpmbuild -ba ~/rpmbuild/SPECS/keyprotect-luks.spec


install: \
	$(DESTDIR)/usr/bin/keyprotect-luks \
	$(DESTDIR)/etc/keyprotect-luks.ini \
	$(DESTDIR)/usr/lib/systemd/system/keyprotect-luks.service \
	$(DESTDIR)/usr/share/doc/keyprotect-luks/README.md \
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

$(DESTDIR)/etc/keyprotect-luks.ini: keyprotect-luks.ini
	install -m 644 -D keyprotect-luks.ini -t "$(DESTDIR)/etc"

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

