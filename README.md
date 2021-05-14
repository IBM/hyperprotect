# Integration of HPCS Key Protect with dm-crypt/LUKS

## Installation

	git clone https://github.ibm.com/gcwilson/keyprotect-luks.git
	sudo make install

## Setup

1. Generate an HPCS Key Protect API key on the IBM Cloud portal

2. Create the initial /etc/keyprotect-luks.ini
   - A skeleton is provided in /usr/share/doc/keyprotect-luks
   - Copy the skeleton to the destination directory
		cp /usr/share/doc/keyprotect-luks/keyprotect-luks.ini /etc
   - Set permission on it
		chown root:root /etc/keyprotect-luks.ini
		chmod 640 /etc/keyprotect-luks.ini
   - Fill in each of the options using information from the IBM Cloud portal, putting a placeholder in default_crk_uuid for now.
		[KP]
		api_key = AB0CdEfGHijKlMN--12OPqRStuv3wx456yZAb7CDEF8g
		region = us-east
		service_instance_id = 01234567-89ab-cdef-0123-456789abcdef
		endpoint_url = https://api.us-east.hs-crypto.cloud.ibm.com:9730
		default_crk_uuid = placeholder

3. Generate a CRK and add it's UUID to /etc/keyprotect-luks.ini
   - Generate a CRK
		keyprotect-luks createcrk --name MyCRKName
   - List the Key Protect keys to get the UUID associated with MyCRKName
		keyprotect-luks list | grep MyCRKName
		fedcba98-7654-3210-fedc-ba9876543210	MyCRKName
   - Edit /etc/keyprotect-luks.ini to set default_crk_uuid
		[KP]
		api_key = AB0CdEfGHijKlMN--12OPqRStuv3wx456yZAb7CDEF8g
		region = us-east
		service_instance_id = 01234567-89ab-cdef-0123-456789abcdef
		endpoint_url = https://api.us-east.hs-crypto.cloud.ibm.com:9730
		default_crk_uuid = fedcba98-7654-3210-fedc-ba9876543210

4. For dm-crypt keys:
    - Generate a random wrapped key and store it in the /var/lib/keyprotect-luks/login directory
		keyprotect-luks genwrap > /var/lib/keyprotect-luks/login/dmcrypt:key1
    - Use dmsetup to setup a crypt target for the block device, assuming /dev/loop0 as the block device for this example and secrets as the mapped name
		dmsetup create secrets --table "0 $(blockdev --getsz /dev/loop0) crypt aes-xts-plain64 :32:logon:dmcrypt:key1 0 /dev/loop0 0"
    - Mount the encrypted device called "secrets" on a mountpoint called "/secrets"
		mkdir /secrets
		mount /dev/mapper/secrets /secrets

5. For LUKS passphrases:
   - Wrap your passphrase and store it in the var/lib/keyprotect-luks/user directory
		keyprotect-luks wrap --dek MyPassPhrase > /var/lib/keyprotect-luks/user/dmcrypt:key2
   - Use cryptsetup to format the block device, assuming /dev/loop0 as the block device for this example
		cryptsetup luksFormat --type luks2 /dev/loop0
   - Provide MyPassPhase as the passphrase when prompted
   - Open the LUKS volume and map it to the name "secrets"
		cryptsetup luksOpen /dev/loop0 secrets
   - Add a key token to the LUKS header
		cryptsetup token add /dev/mapper/secrets --key-description dmcrypt:key2
    - Mount the encrypted device called "secrets" on a mountpoint called "/secrets"
		mkdir /secrets
		mount /dev/mapper/secrets /secrets

6. Enable the keyprotect-luks systemd service:
		systemctl enable keyprotect-luks

7. Reboot

8. You should see a logon key type called dmcrypt:key1 and user key type called dmcrypt:key2 in root's @u keyring
		keyctl show @s

9. You can directly use they keys with dmsetup create

10. cryptsetup should NOT prompt for a key when you luksOpen the LUKS device

** IMPORTANT **

If you use mosh to login remotely, root will not have a valid @s keyring and you won't be able to see the keys.  In this case:
		keyctl new_session
		keyctl link @us @s
and you should now be able to show the keys
