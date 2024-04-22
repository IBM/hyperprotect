#!/bin/sh
#
# SPDX-License-Identifier: Apache-2.0
#
# Key Protect Interface for hpcs-for-luks service via Python
#
# George Wilson <gcwilson@linux.ibm.com>, Samuel Matzek <smatzek@us.ibm.com>
#
# Copyright (C) 2021,2024 IBM Corp.
#

type getcmdline > /dev/null 2>&1 || . /lib/dracut-lib.sh

_UTILITY_NAME=hpcs-for-luks

#
# Set to a non-empty string to enable.
# Attention: Enabling debug leaks secrets into the systemd journal.
#
_DEBUG=

parse_ini() {
	while read INI_LINE; do
		INI_LINE=${INI_LINE%%#*} # Eat comments
		case $INI_LINE in
			api_key*)
				_API_KEY=$(echo ${INI_LINE##*=}) # Take the RHS and let echo strip the space
				;;
			region*)
				_REGION=$(echo ${INI_LINE##*=})
				;;
			endpoint_url*)
				_ENDPOINT_URL=$(echo ${INI_LINE##*=})
				;;
			service_instance_id*)
				_SERVICE_INSTANCE_ID=$(echo ${INI_LINE##*=})
				;;
			default_crk_uuid*)
				_DEFAULT_CRK_UUID=$(echo ${INI_LINE##*=})
				;;
			iam_endpoint_url*)
				_IAM_ENDPOINT_URL=$(echo ${INI_LINE##*=})
				;;
		esac
	done < /etc/${_UTILITY_NAME}.ini
}

authenticate() {
	_AUTH_JSON=$(curl -X POST \
	"$_IAM_ENDPOINT_URL/identity/token" \
	--header 'Content-Type: application/x-www-form-urlencoded' \
	--header 'Accept: application/json' \
	--data-urlencode 'grant_type=urn:ibm:params:oauth:grant-type:apikey' \
	--data-urlencode "apikey=$_API_KEY")
}

parse_authtoken() {
	_AUTH_TOKEN=${_AUTH_JSON##\{\"access_token\"\:\"}
	_AUTH_TOKEN=${_AUTH_TOKEN%%\"*}
}

list_keys() {
	curl -X GET \
	$_ENDPOINT_URL/api/v2/keys \
	-H 'accept: application/vnd.ibm.kms.key+json' \
	-H "authorization: Bearer $_AUTH_TOKEN" \
	-H "bluemix-instance: $_SERVICE_INSTANCE_ID"

}

unwrap_key() {
	curl -X POST \
	$_ENDPOINT_URL/api/v2/keys/$_DEFAULT_CRK_UUID/actions/unwrap \
	-H 'accept: application/json' \
	-H "authorization: Bearer $_AUTH_TOKEN" \
	-H "bluemix-instance: $_SERVICE_INSTANCE_ID" \
	-H 'content-type: application/vnd.ibm.kms.key_action_unwrap+json' \
	-d "{
		    \"ciphertext\": \"$_CIPHERTEXT\"
  	    }"
}

parse_plaintext_json() {
	_BASE64_PLAINTEXT=${_PLAINTEXT_JSON##\{\"plaintext\"\:\"}
	_BASE64_PLAINTEXT=${_BASE64_PLAINTEXT%%\"*}
}

retry() {
        local __MAX=10
        local __COUNT=0
        $1
        __RC=$?
        while [ $__RC -ne 0 -a $__COUNT -lt $__MAX ]; do
                sleep 1
                echo "${_UTILITY_NAME}-dracut.sh: Retrying $1: $__COUNT"
                $1
                __RC=$?
                __COUNT=$((__COUNT + 1))
        done
        if [ $__COUNT -eq $__MAX ]; then
                echo "${_UTILITY_NAME}-dracut.sh: Max retries of $1 exceeded"
                return 1
        fi
	return $__RC
}


if grep -q "rd.${_UTILITY_NAME}" /proc/cmdline; then

	[ -n "$_DEBUG" ] && echo "Debug output from ${_UTILITY_NAME}"

	parse_ini
	[ -n "$_DEBUG" ] && echo "api_key = $_API_KEY"
	[ -n "$_DEBUG" ] && echo "region = $_REGION"
	[ -n "$_DEBUG" ] && echo "endpoint_url = $_ENDPOINT_URL"
	[ -n "$_DEBUG" ] && echo "service_instance_id = $_SERVICE_INSTANCE_ID"
	[ -n "$_DEBUG" ] && echo "default_crk_uuid = $_DEFAULT_CRK_UUID"
	if [ "$_API_KEY" == "TPM" ]; then
		if grep -q "rd.tss" /proc/cmdline; then
			if [ -x /usr/bin/tpm_unsealdata ]; then
				echo "Unsealing API key from TPM"
				_API_KEY=$(tpm_unsealdata -z -i /var/lib/${_UTILITY_NAME}/api-key-blob.txt)
			else
				echo "${_UTILITY_NAME}-dracut.sh: The tpm_unsealdata command cannot be found"
				exit 1
			fi
		else
			echo "${_UTILITY_NAME}-dracut.sh: api_key = TPM in the ini file but rd.tss is not set on the cmdline"
			exit 1
		fi
	fi

	retry authenticate
	if [ $? -ne 0 ]; then
		echo "${_UTILITY_NAME}-dracut.sh: cannot authenticate"
		exit 1
	fi

	parse_authtoken
	[ -n "$_DEBUG" ] && echo $_AUTH_TOKEN
	[ -n "$_DEBUG" ] && list_keys

	_CIPHERTEXT=$(cat /var/lib/${_UTILITY_NAME}/user/luks:root)
	if [ $? -ne 0 ]; then
		echo "${_UTILITY_NAME}-dracut.sh: cannot obtain wrapped rootfs LUKS key"
		exit 1
	fi

	_PLAINTEXT_JSON=$(unwrap_key)
	if [ $? -ne 0 ]; then
		echo "${_UTILITY_NAME}-dracut.sh: cannot unwrap rootfs LUKS key"
		exit 1
	fi
	[ -n "$_DEBUG" ] && echo $_PLAINTEXT_JSON

	parse_plaintext_json
	[ -n "$_DEBUG" ] && echo $_BASE64_PLAINTEXT
	printf "%s" $_BASE64_PLAINTEXT | base64 --decode | keyctl padd user "luks:root" @u
	if [ $? -ne 0 ]; then
		echo "${_UTILITY_NAME}-dracut.sh: cannot add rootfs LUKS key to @u keyring"
		exit 1
	fi

	keyctl show @u

	# When using systemd in dracut for encrypted root partitions we need to pivot back
	# to the initramfs on shutdown to gracefully unmount the root mount. Note that
	# 90crypt's non-systemd path and 90lvm trigger need_shutdown, so this need_shutdown
	# call specifically ensures the shutdown pivot for encrypted roots.
	need_shutdown
else
	echo "${_UTILITY_NAME}-dracut.sh: rd.${_UTILITY_NAME} is not set on the cmdline"
fi
