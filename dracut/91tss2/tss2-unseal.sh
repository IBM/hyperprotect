#!/bin/bash -x
#
# SPDX-License-Identifier: Apache-2.0
#
# Unseal script using IBM's TSS2
#
# George Wilson <gcwilson@linux.ibm.com>, Samuel Matzek <smatzek@us.ibm.com>,
# Kenneth Goldman <kgoldman@linux.ibm.com>
#
# Copyright (C) 2024 IBM Corp.
#

export TPM_ENCRYPT_SESSIONS=0
export TPM_INTERFACE_TYPE=dev
export TPM_DEVICE=/dev/tpm0

set -e

function gethandle() {
	read a b; echo $b
}

function calcmask() {
	MASK=0
	while [ "$1" != "" ]; do
		MASK=$(($MASK | (1 << $1)))
		shift
	done
	printf "%06x\n" $MASK
}

function cleanup() {
	RC=$?
	[ ! -z "$HANDLE3" ] && tssflushcontext -ha $HANDLE3
	[ ! -z "$HANDLE2" ] && tssflushcontext -ha $HANDLE2
	[ ! -z "$HANDLE1" ] && tssflushcontext -ha $HANDLE1
	exit $RC
}

function check_and_gethandle() {
	__OUTPUT=$($*)
	RC=$?
	if [ $RC -eq 0 ]; then
		echo ${__OUTPUT#* }
	else
		echo __OUTPUT 1>&2
	fi
	return $RC
}


PROGNAME=${0##*/}

if [ $# -lt 2 -o "$1" == "--help" ]; then
	echo "$PROGNAME: usage [input file basename] [output file]" 1>&2
	exit 1
fi
ENCSECRET_BASENAME="$1"
shift
SECRET="$1"
shift

ENCSECRETPRIV="${ENCSECRET_BASENAME}-priv.bin"
ENCSECRETPUB="${ENCSECRET_BASENAME}-pub.bin"
ENCSECRETPCRS="${ENCSECRET_BASENAME}-pcrs"

trap cleanup EXIT

PCRS=$(cat "$ENCSECRETPCRS")
MASK=$(calcmask $PCRS)

> "out-pcrs.txt"
for PCR in $PCRS; do
	echo -n "PCR[$PCR]=" >> "out-pcrs.txt"
        tsspcrread -ha $PCR -halg sha256 -ns >> "out-pcrs.txt"
done

HANDLE1=$(check_and_gethandle tsscreateprimary -hi o -ecc nistp256)
echo $HANDLE1
HANDLE2=$(check_and_gethandle tssload -hp $HANDLE1 -ipr "$ENCSECRETPRIV" -ipu "$ENCSECRETPUB")
echo $HANDLE2
HANDLE3=$(check_and_gethandle tssstartauthsession -se p -halg sha256)
echo $HANDLE3
tsspolicypcr -halg sha256 -ha $HANDLE3 -bm $MASK
tssunseal -ha $HANDLE2 -of "$SECRET" -se0 $HANDLE3 1
