#!/bin/sh

parse_ini() {
	while read INI_LINE; do
		INI_LINE=${INI_LINE%%#*} # Eat comments
		case $INI_LINE in
			api_key*)
				_API_KEY=`echo ${INI_LINE##*=}` # Take the RHS and let echo strip the space
				;;
			region*)
				_REGION=`echo ${INI_LINE##*=}`
				;;
			endpoint_url*)
				_ENDPOINT_URL=`echo ${INI_LINE##*=}`
				;;
			service_instance_id*)
				_SERVICE_INSTANCE_ID=`echo ${INI_LINE##*=}`
				;;
			default_crk_uuid*)
				_DEFAULT_CRK_UUID=`echo ${INI_LINE##*=}`
				;;
		esac
	done < /etc/keyprotect-luks.ini
}

authenticate() {
	_AUTH_JSON=`curl -X POST \
	"https://iam.cloud.ibm.com/identity/token" \
	--header 'Content-Type: application/x-www-form-urlencoded' \
	--header 'Accept: application/json' \
	--data-urlencode 'grant_type=urn:ibm:params:oauth:grant-type:apikey' \
	--data-urlencode "apikey=$_API_KEY"`
}

parse_authtoken() {
	#echo $_AUTH_JSON
	#echo ${_AUTH_JSON##\{\"access_token\"\:\"}
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


if grep -q "rd.keyprotect-luks" /proc/cmdline; then
	#echo "Hello from keyprotect-luks"
	parse_ini
	#echo "api_key = $_API_KEY"
	#echo "region = $_REGION"
	#echo "endpoint_url = $_ENDPOINT_URL"
	#echo "service_instance_id = $_SERVICE_INSTANCE_ID"
	#echo "default_crk_uuid = $_DEFAULT_CRK_UUID"
	authenticate
	parse_authtoken
	#echo $_AUTH_TOKEN
	#list_keys
	_CIPHERTEXT=`cat /var/lib/keyprotect-luks/user/luks:root`
	_PLAINTEXT_JSON=`unwrap_key`
	#echo $_PLAINTEXT_JSON
	parse_plaintext_json
	#echo $_BASE64_PLAINTEXT
	printf "%s" $_BASE64_PLAINTEXT | base64 --decode
else
	echo "keyprotect-luks says rd.keyprotect-luks is not set on the cmdline"
fi

#/usr/bin/curl http://crimini9.aus.stglabs.ibm.com/testpage.html

#region = us-east # Another comment
#service_instance_id = 8b12b984-5c42-4324-8a50-c4bc4a223154
#endpoint_url = https://api.us-east.hs-crypto.cloud.ibm.com:9730
#default_crk_uuid = 1cbf4897-de35-48d2-b393-eec5adf117a0
