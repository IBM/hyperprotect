#!/bin/sh
#
# SPDX-License-Identifier: Apache-2.0
#
# Read sealed blobs with names matching keyring dscriptions from well-defined
# location and unseal to keyring
#
# George Wilson <gcwilson@linux.ibm.com>
#
# Copyright (C) 2024 IBM Corp.
#
# Prerequisites, assumptions, characteristics:
#     - The boot volume is uniquely labeled /boot
#     - Sealed key blobs are in the boot voume under /var/lib/tss2
#     - Key blob base names are used for keyring key descriptions
#     - Key blob base suffizes are always -priv.bin and -pub.bin
#     - ASCII PCR lists against which key blob bases are sealed are in -pcr files
#

PROGNAME=${0##*/}

BLOB_SUBDIR=/var/lib/tss2
BLOB_PATH=/boot"${BLOB_SUBDIR}"
SECRETS_TMP=/tmp/tss2

echo "tss2: got here"

cleanup() {
	rm -f "${SECRETS_TMP}/${BLOB_BASENAME}.out"
	popd
	umount /boot
}

retry() {
        local __MAX=10
        local __COUNT=0
        $*
        __RC=$?
        while [ $__RC -ne 0 -a $__COUNT -lt $__MAX ]; do
                sleep 1
                echo "tss2: Retrying $*: $__COUNT"
                $1
                __RC=$?
                __COUNT=$((__COUNT + 1))
        done
        if [ $__COUNT -eq $__MAX ]; then
                echo "tss2: Max retries of $* exceeded" 1>&2
                return 1
        fi
        return $__RC
}

trap cleanup EXIT

#
# Make /boot mountpoint
#

if [ ! -d /boot ]; then
	mkdir /boot
	RC=$?
	if [ $RC -ne 0 ]; then
		echo "$PROGNAME: cannot mkdir /boot, rc = $RC" 1>&2
		exit 1
	fi
fi

#
# Mount fs labeled /boot on /boot
#

if ! mountpoint /boot; then
	retry mount LABEL=/boot /boot
	RC=$?
	if [ $RC -ne 0 ]; then
		echo "$PROGNAME: cannot mount /boot, rc = $RC" 1>&2
		exit 1
	fi
fi

#
# Check for key blob path
#

if [ ! -d "${BLOB_PATH}" ]; then
	echo "$PROGNAME: cannot find ${BLOB_PATH}" 1>&2
	exit 1
fi

#
# Make a place for secrets.
#

mkdir -p ${SECRETS_TMP}

#
# Iterate over keys
#

pushd "${BLOB_PATH}"

for TYPE in *; do
	pushd "${TYPE}"
	for PUB_BLOB in *-pub.bin; do
		BLOB_BASENAME="${PUB_BLOB%-pub.bin}"
		tss2-unseal.sh "$BLOB_BASENAME" "${SECRETS_TMP}/${BLOB_BASENAME}.out"
		if [ $? -ne 0 ]; then
			echo "tss2: Unseal failed" 1>&2
			exit 1
		fi
		keyctl padd ${TYPE} "${BLOB_BASENAME}" @u < "${SECRETS_TMP}/${BLOB_BASENAME}.out"
		rm -f "${SECRETS_TMP}/${BLOB_BASENAME}.out"
	done
	popd
done

