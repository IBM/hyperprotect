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

PROGNAME=${0##*/}

if [ $# -lt 3 -o "$1" == "--help" ]; then
	echo "$PROGNAME: usage [input file basename] [output file] [PCRs]" 1>&2
	exit 1
fi
ENCSECRET_BASENAME="$1"
shift
SECRET="$1"
shift

ENCSECRETPRIV="${ENCSECRET_BASENAME}-priv.bin"
ENCSECRETPUB="${ENCSECRET_BASENAME}-pub.bin"

trap cleanup EXIT

MASK=$(calcmask $*)

HANDLE1=$(tsscreateprimary -hi n -ecc nistp256 | gethandle)
echo $HANDLE1
HANDLE2=$(tssload -hp $HANDLE1 -ipr "$ENCSECRETPRIV" -ipu "$ENCSECRETPUB" | gethandle)
echo $HANDLE2
HANDLE3=$(tssstartauthsession -se p -halg sha256 | gethandle)
echo $HANDLE3
tsspolicypcr -halg sha256 -ha $HANDLE3 -bm $MASK
tssunseal -ha $HANDLE2 -of "$SECRET" -se0 $HANDLE3 1
