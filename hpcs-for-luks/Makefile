PACKAGENAME=hpcs-for-luks
PACKAGEVER=1.1

UTILITYNAME=hpcs-for-luks

TARFILE=${PACKAGENAME}-${PACKAGEVER}.tar.gz
RPMFILE=${PACKAGENAME}-${PACKAGEVER}-1.el8.noarch.rpm
DEBFILE=${PACKAGENAME}_${PACKAGEVER}_all.deb

COUNTFILE=${HOME}/.${PACKAGENAME}-key-count
BATCHFILE=${HOME}/.${PACKAGENAME}-batchfile
STATFILE=${HOME}/.${PACKAGENAME}-statfile

RPMROOT=${HOME}/rpm-user
DEB_BUILDROOT=${HOME}/deb-buildroot/${PACKAGENAME}_${PACKAGEVER}_all

BASE_KEYNAME=${PACKAGENAME}-build
KEYNAME=${BASE_KEYNAME}-$${KEYCOUNT}
PUBKEYFILE=./${KEYNAME}.asc
PASSPHRASEFILE=${HOME}/.${KEYNAME}.passphrase

.PHONY: all clean dist pre-dist pre-dist-deb deb incr_gen_key sign rpm install install-dracut

all: dist

clean:
	rm -f ${TARFILE}
	rm -f ${RPMFILE}
	rm -f ${DEBFILE}
	rm -f SHA256SUMS

dist: pre-dist pre-dist-deb sign
	sha256sum ${RPMFILE} > SHA256SUMS
	sha256sum ${DEBFILE} >> SHA256SUMS

pre-dist: rpm
	cp -p ~/rpmbuild/RPMS/noarch/${RPMFILE} .

pre-dist-deb: deb
	cp -p ${DEB_BUILDROOT}/../${DEBFILE} .

deb:
	rm -fr ${DEB_BUILDROOT}
	mkdir -p ${DEB_BUILDROOT}
	make DESTDIR=${DEB_BUILDROOT} install
	cp -pr DEBIAN ${DEB_BUILDROOT}
	dpkg-deb --build --root-owner-group ${DEB_BUILDROOT}

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
	echo $${PASSPHRASE} > ${PASSPHRASEFILE}; \
	\
	echo "%echo Generating a GPG signing key for the ${PACKAGENAME} package . . . "  > ${BATCHFILE}; \
	echo "Key-Type: RSA" >> ${BATCHFILE}; \
	echo "Key-Length: 2048" >> ${BATCHFILE}; \
	echo "Subkey-Type: RSA" >> ${BATCHFILE}; \
	echo "Subkey-Length: 2048" >> ${BATCHFILE}; \
	echo "Name-Real: ${KEYNAME}" >> ${BATCHFILE}; \
	echo "Name-Comment: IBM Key Protect LUKS Integration Package Signing Key" >> ${BATCHFILE}; \
	echo "Name-Email: gcwilson@us.ibm.com" >> ${BATCHFILE}; \
	echo "Expire-Date: 0" >> ${BATCHFILE}; \
	echo "Passphrase: $${PASSPHRASE}" >> ${BATCHFILE}; \
	echo "%commit" >> ${BATCHFILE}; \
	echo "%echo done" >> ${BATCHFILE}; \
	gpg2 --status-file=${STATFILE} --gen-key --pinentry-mode=loopback --batch --with-colons < ${BATCHFILE} 1>&2; \
	rm -f ${BATCHFILE}; \
	cat ${STATFILE}; 1>&2 \
	rm -f ${STATFILE}; \
	gpg --export -a ${KEYNAME} > ${PUBKEYFILE}; \
	rpm --root ${RPMROOT} --import ${PUBKEYFILE}

sign:
	if [ ! -f ${COUNTFILE} ]; then \
		KEYCOUNT=0; \
	else \
	        KEYCOUNT=`cat ${COUNTFILE}`; \
	fi; \
	rpm --define "%_gpg_name ${KEYNAME}" \
	    --define "%__gpg_sign_cmd %{__gpg} --force-v3-sigs \
	                                     --batch \
					     --verbose \
					     --no-armor \
					     --passphrase-file=${PASSPHRASEFILE} \
					     --pinentry-mode=loopback \
					     --no-secmem-warning \
					     -u \"%{_gpg_name}\" \
					     -sbo %{__signature_filename} \
					     --digest-algo sha256 \
					     %{__plaintext_filename}" \
	  --addsign ${RPMFILE}

rpm:
	rm -f ${TARFILE}
	tar --xform='s/^/${PACKAGENAME}-${PACKAGEVER}\//' -cpzf ${TARFILE} *
	cp -p ${TARFILE} ~/rpmbuild/SOURCES
	cp -p ${PACKAGENAME}.spec ~/rpmbuild/SPECS
	rpmbuild -ba ~/rpmbuild/SPECS/${PACKAGENAME}.spec


install: \
	$(DESTDIR)/usr/bin/${UTILITYNAME} \
	$(DESTDIR)/etc/${UTILITYNAME}.ini \
	$(DESTDIR)/usr/lib/systemd/system/${UTILITYNAME}.service \
	$(DESTDIR)/usr/lib/systemd/system/${UTILITYNAME}-wipe.service \
	$(DESTDIR)/usr/share/doc/${PACKAGENAME}/README.md \
	$(DESTDIR)/usr/share/man/man1/${UTILITYNAME}.1.gz \
	$(DESTDIR)/var/lib/${UTILITYNAME} \
	$(DESTDIR)/var/lib/${UTILITYNAME}/logon \
	$(DESTDIR)/var/lib/${UTILITYNAME}/user

install-dracut: \
	$(DESTDIR)/usr/lib/dracut/modules.d/85${UTILITYNAME} \
	$(DESTDIR)/usr/lib/dracut/modules.d/85${UTILITYNAME}/${UTILITYNAME}.sh \
	$(DESTDIR)/usr/lib/dracut/modules.d/85${UTILITYNAME}/module-setup.sh \
	$(DESTDIR)/etc/dracut.conf.d/${UTILITYNAME}.conf \
	$(DESTDIR)/usr/lib/dracut/modules.d/83tss \
	$(DESTDIR)/usr/lib/dracut/modules.d/83tss/module-setup.sh \
	$(DESTDIR)/usr/lib/dracut/modules.d/83tss/start-tcsd.sh \
	$(DESTDIR)/usr/lib/dracut/modules.d/83tss/stop-tcsd.sh \
	$(DESTDIR)/usr/lib/dracut/modules.d/83tss/run-tss-cmds.sh \
	$(DESTDIR)/etc/dracut.conf.d/tss.conf

$(DESTDIR)/usr/bin/${UTILITYNAME}: ${UTILITYNAME}
	install -m 755 -D ${UTILITYNAME} -t "$(DESTDIR)/usr/bin"

$(DESTDIR)/usr/lib/systemd/system/${UTILITYNAME}.service: ${UTILITYNAME}.service
	install -m 644 -D ${UTILITYNAME}.service -t "$(DESTDIR)/usr/lib/systemd/system"

$(DESTDIR)/usr/lib/systemd/system/${UTILITYNAME}-wipe.service: ${UTILITYNAME}-wipe.service
	install -m 644 -D ${UTILITYNAME}-wipe.service -t "$(DESTDIR)/usr/lib/systemd/system"

$(DESTDIR)/usr/share/doc/${PACKAGENAME}/README.md: README.md
	install -m 644 -D README.md -t "$(DESTDIR)/usr/share/doc/${PACKAGENAME}"

$(DESTDIR)/etc/${UTILITYNAME}.ini: ${UTILITYNAME}.ini
	install -m 644 -D ${UTILITYNAME}.ini -t "$(DESTDIR)/etc"

$(DESTDIR)/usr/share/man/man1/${UTILITYNAME}.1.gz: ${UTILITYNAME}.1
	mkdir -p "$(DESTDIR)/usr/share/man/man1"
	gzip <${UTILITYNAME}.1 >"$(DESTDIR)/usr/share/man/man1/${UTILITYNAME}.1.gz"
	chmod 644 "$(DESTDIR)/usr/share/man/man1/${UTILITYNAME}.1.gz"

$(DESTDIR)/var/lib/${UTILITYNAME}:
	install -m 755 -d $(DESTDIR)/var/lib/${UTILITYNAME}

$(DESTDIR)/var/lib/${UTILITYNAME}/logon:
	install -m 755 -d $(DESTDIR)/var/lib/${UTILITYNAME}/logon

$(DESTDIR)/var/lib/${UTILITYNAME}/user:
	install -m 755 -d $(DESTDIR)/var/lib/${UTILITYNAME}/user

$(DESTDIR)/usr/lib/dracut/modules.d/85${UTILITYNAME}:
	install -m 755 -d $(DESTDIR)/usr/lib/dracut/modules.d/85${UTILITYNAME}

$(DESTDIR)/usr/lib/dracut/modules.d/85${UTILITYNAME}/${UTILITYNAME}.sh: dracut/85${UTILITYNAME}/${UTILITYNAME}.sh
	install -m 755 -D dracut/85${UTILITYNAME}/${UTILITYNAME}.sh -t "$(DESTDIR)/usr/lib/dracut/modules.d/85${UTILITYNAME}"

$(DESTDIR)/usr/lib/dracut/modules.d/85${UTILITYNAME}/module-setup.sh: dracut/85${UTILITYNAME}/module-setup.sh
	install -m 755 -D dracut/85${UTILITYNAME}/module-setup.sh -t "$(DESTDIR)/usr/lib/dracut/modules.d/85${UTILITYNAME}"

$(DESTDIR)/etc/dracut.conf.d/${UTILITYNAME}.conf: dracut/${UTILITYNAME}.conf
	install -m 644 -D dracut/${UTILITYNAME}.conf -t "$(DESTDIR)/etc/dracut.conf.d"

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

