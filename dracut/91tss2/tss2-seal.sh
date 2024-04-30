#!/bin/bash -x
#
# SPDX-License-Identifier: Apache-2.0
#
# Seal script using IBM's TSS2
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
	[ ! -z "$HANDLE1" ] && tssflushcontext -ha $HANDLE1
	[ -f "$POLICYPCRLIST" ] && rm -f "$POLICYPCRLIST"
	[ -f "$POLICYPCR" ] && rm -f "$POLICYPCR"
	[ -f "$POLICY" ] && rm -f "$POLICY"
	exit $RC
}

PROGNAME=${0##*/}

if [ $# -lt 3 -o "$1" == "--help" ]; then
	echo "$PROGNAME: usage [input file] [output file basename] [PCRs]" 1>&2
	exit 1
fi
SECRET="$1"
shift
ENCSECRET_BASENAME="$1"
shift

POLICYPCRLIST="policypcrlist.txt"
POLICYPCR="policypcr.txt"
POLICY="policy.bin"
ENCSECRETPRIV="${ENCSECRET_BASENAME}-priv.bin"
ENCSECRETPUB="${ENCSECRET_BASENAME}-pub.bin"

trap cleanup EXIT

MASK=$(calcmask $*)

HANDLE1=$(tsscreateprimary -hi n -ecc nistp256 | gethandle)
echo $HANDLE1
> "$POLICYPCRLIST"
for PCR in $*; do
	tsspcrread -ha $PCR -halg sha256 -ns >> "$POLICYPCRLIST"
done
tsspolicymakerpcr -halg sha256 -bm $MASK -if "$POLICYPCRLIST" -v -pr -of "$POLICYPCR"
tsspolicymaker -halg sha256 -if "$POLICYPCR" -of "$POLICY" -pr -v
tsscreate -hp $HANDLE1 -nalg sha256 -bl -kt f -kt p -opr "$ENCSECRETPRIV" -opu "$ENCSECRETPUB" -if "$SECRET" -pol "$POLICY"
