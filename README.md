# Integration of HPCS Key Protect with dm-crypt/LUKS

## Installation

	git clone https://github.ibm.com/gcwilson/hpcs-for-luks.git
	sudo make install

## Setup

1. Generate an HPCS Key Protect API key on the IBM Cloud portal

2. Install python3 and python3-cryptography packages

   If using an rpm-based OS:

		dnf install python3 python3-cryptography

   If using an deb-based OS:

		apt-get install python3 python3-cryptography

   - **IMPORTANT:** You'll have Rust problems if you try to use pip to install Python Cryptography.

3. Install IBM Key Protect

	pip3 install keyprotect

4. Edit the initial /etc/hpcs-for-luks.ini

   - Fill in each of the options using information from the IBM Cloud portal, putting a placeholder in default_crk_uuid for now:

			[KP]
			region = us-east
			endpoint_url = https://api.us-east.hs-crypto.cloud.ibm.com:9730
			service_instance_id = 01234567-89ab-cdef-0123-456789abcdef
			api_key = AB0CdEfGHijKlMN--12OPqRStuv3wx456yZAb7CDEF8g
			default_crk_uuid = placeholder

5. Generate a random CRK and add its UUID to /etc/hpcs-for-luks.ini

   - Generate a random CRK

			hpcs-for-luks create --crk --gen --name MyCRKName

   - List the Key Protect keys to get the UUID associated with MyCRKName

			hpcs-for-luks list | grep MyCRKName
			fedcba98-7654-3210-fedc-ba9876543210	MyCRKName

   - Edit /etc/hpcs-for-luks.ini to set default_crk_uuid

			[KP]
			api_key = AB0CdEfGHijKlMN--12OPqRStuv3wx456yZAb7CDEF8g
			region = us-east
			service_instance_id = 01234567-89ab-cdef-0123-456789abcdef
			endpoint_url = https://api.us-east.hs-crypto.cloud.ibm.com:9730
			default_crk_uuid = fedcba98-7654-3210-fedc-ba9876543210

6. Note on the dm-crypt and LUKS insturctions below:

    - The following examples assume that /dev/loop0 is the encrypted block device.  Substitute it with the actual encrypted block device if not using /dev/loop0.

7. For dm-crypt keys:

    - Enable the hpcs-for-luks systemd service

			systemctl enable hpcs-for-luks

    - Generate a random wrapped key and store it in the /var/lib/hpcs-for-luks/logon directory

			hpcs-for-luks wrap --gen > /var/lib/hpcs-for-luks/logon/dmcrypt:key1

    - After creating wrapped keys, populate the kernel keyring by either

			shutdown -r now

      so that the hpcs-for-luks systemd service will populate it or

			hpcs-for-luks process

      to populate it immediately.

    - Use dmsetup to setup a crypt target for the block device, assuming /dev/loop0 as the block device for this example and secrets as the mapped name

			dmsetup create secrets --table "0 $(blockdev --getsz /dev/loop0) crypt aes-xts-plain64 :32:logon:dmcrypt:key1 0 /dev/loop0 0"

   - Format the mapped device with your favorite filesystem, in this case ext4:

			mkfs -t ext4 /dev/mapper/secrets

    - Mount the encrypted device called "secrets" on a mountpoint called "/secrets"

			mkdir /secrets
			mount /dev/mapper/secrets /secrets

8. For LUKS passphrases:

    - Enable the hpcs-for-luks systemd service

			systemctl enable hpcs-for-luks

   - Wrap your passphrase and store it in the var/lib/hpcs-for-luks/user directory

			echo -n 'MyPassPhrase' | hpcs-for-luks wrap > /var/lib/hpcs-for-luks/user/dmcrypt:key2

   - After creating wrapped keys, populate the kernel keyring by either

			shutdown -r now

     so that the hpcs-for-luks systemd service will populate it or

			hpcs-for-luks process

     to populate it immediately.

   - Use cryptsetup to format the block device, assuming /dev/loop0 as the block device for this example

			cryptsetup luksFormat --type luks2 /dev/loop0

   - Provide MyPassPhase as the passphrase when prompted

   - Open the LUKS volume and map it to the name "secrets"

			cryptsetup luksOpen /dev/loop0 secrets

   - Format the mapped device with your favorite filesystem, in this case ext4:

			mkfs -t ext4 /dev/mapper/secrets

   - Add a key token to the LUKS header

			cryptsetup token add /dev/loop0 --key-description dmcrypt:key2

   - Mount the encrypted device called "secrets" on a mountpoint called "/secrets"

			mkdir /secrets
			mount /dev/mapper/secrets /secrets

9. Enable the hpcs-for-luks systemd service:

		systemctl enable hpcs-for-luks

10. Enable the remote cryptsetup target

		systemctl enable remote-cryptsetup.target

11. Reboot

12. You should see a logon key type called dmcrypt:key1 and user key type called dmcrypt:key2 in root's @u keyring

		keyctl show @s

13. You can directly use they keys with dmsetup create

14. cryptsetup should NOT prompt for a key when you luksOpen the LUKS device

**IMPORTANT**

The above instructions assume that the user directly logs in as root; not indirectly via su or sudo from another user.  If it's necessary to login as an ordinary user and switch to root, please refer to this article: https://mjg59.dreamwidth.org/37333.html


If you use mosh to login remotely, root will not have a valid @s keyring and you won't be able to see and use the keyring keys.  In this case:

	keyctl new_session
	keyctl link @us @s

and you should now be able to show the keys

	keyctl show @s

## Notes on Reducing cryptsetup Memory

When executing multiple cryptsetup instances in parallel, as occurs setting up multiple encrypted volumes via systemd, beware that the LUKS2 default KDF, Argon2i, will consume large amounts of memory.  This is by design because it utilizes a memory-hard problem.  However, such a configuration can consume all system memory trigger the OOM killer during bootup.

There are a couple of different options to handle this situation.

1. When formatting encrypted volumes with cryptsetup luksFormat, use PKKDF2, which implements a time-hard rather than memory-hard problem.  Updating the example above:

		cryptsetup luksFormat --type luks2 --pbkdf pbkdf2 /dev/loop0

2. By default, Argon2i uses half the available system memory.  It is possible to reduce Argon2i memory utilization using the --pbkdf-memory option.  Updating the same example to limit Argon2i to 256K:

		cryptsetup luksFormat --type luks2 --pbkdf-memory 256 /dev/loop0

It is worth noting that /usr/sbin/cryptsetup luksOpen offers a --serialize-memory-hard-pbkdf option to serialize cryptsetup memory-hard KDF instances.  However, /usr/lib/systemd/systemd-cryptsetup, utilized by systemd to setup encrypted volumes during boot, does not.

Information taken from https://bugzilla.redhat.com/show_bug.cgi?id=1969569 and https://gitlab.com/cryptsetup/cryptsetup/-/issues/372.

## Sealing the API key to TPM 1.2 PCRs

1. Enable the vTPM 1.2 from the HMC or disable and re-enable it in order to clear it

2. Install TrouSerS and tpm-tools and ensure tcsd is running

		dnf install trousers tpm-tools
		systemctl enable tcsd
		systemctl start tcsd

3. Take ownership of the vTPM using well-known secrets

		tpm_takeownership -y -z

4. Create a file containing the API key

		echo -n 'AB0CdEfGHijKlMN--12OPqRStuv3wx456yZAb7CDEF8g' > api-key.txt
	
5. Seal the key in the file to PCRs, in this example PCR[4] and PCR[5]

		tpm_sealdata -p 4 -p 5 -z --infile api-key.txt --outfile /var/lib/hpcs-for-luks/api-key-blob.txt

6. Remove the file containing the API key plaintext

		rm api-key.txt

7. Edit /etc/hpcs-for-luks.ini and assign api_key the special value "TPM"

		[KP]
		api_key = TPM
		region = us-east
		service_instance_id = 01234567-89ab-cdef-0123-456789abcdef
		endpoint_url = https://api.us-east.hs-crypto.cloud.ibm.com:9730
		default_crk_uuid = fedcba98-7654-3210-fedc-ba9876543210
 
## Use

### dmsetup Example

Here's an example dmsetup command assuming:

   - /dev/loop0 is the block device to be encrypted
   - dmcrypt:mykey1 is the description of a 32-byte logon key present in the kernel keyring

			dmsetup create secrets --table "0 $(blockdev --getsz /dev/loop0) crypt aes-xts-plain64 :32:logon:dmcrypt:mykey1 0 /dev/loop0 0"
			mount /dev/mapper/secrets /secrets

### cryptsetup Example

Here's an example of how to setup a key token on a LUKS-encrypted device assuming:

   - /root/secrets.img is a loopback file to be encrypted
   - /dev/loop0 is the block device associated with /root/secrets.img with losetup
   - cryptsetup:mykey2 is the description of a user key present in the kernel keyring that contains the LUKS passphrase provided to luksFormat

			losetup -f /root/secrets.img
			cryptsetup luksFormat --type luks2 /dev/loop0
			cryptsetup token add --key-description cryptsetup:mykey2 /dev/loop0
			cryptsetup luksDump /dev/loop0
			losetup -d /dev/loop0
			cryptsetup luksOpen /root/secrets.img secrets
			mount /dev/mapper/secrets /secrets

## Example /etc/crypttab entry

	#volume-name encrypted-device key-file options
	secrets /root/secrets.img none _netdev,timeout=1

## Example /etc/fstab entry

	/dev/mapper/secrets   /secrets      ext4    defaults,_netdev 0 0


!!!DRACUT WORK FOR HPCS FOR LUKS IS INCOMPLETE AND SHOULD NOT BE USED YET!!!

First, install the dracut modules by running

	make install-dracut

Add the following Dracut module files to /etc/dracut.conf.d

## Networking in the initramfs

### Dracut modules

#### ifcfg.confg

	add_dracutmodules+=" ifcfg "

#### network.conf

	add_dracutmodules+=" network "

#### network-legacy.conf

	add_dracutmodules+=" network-legacy "

#### network-manager.conf

	add_dracutmodules+=" network-manager "

#### url-lib.conf

	add_dracutmodules+=" url-lib "

### Rebuild initramfs

	dracut --regenerate-all --force --verbose

### Kernel cmdline

Use grub2-editenv to append the following options to the kernel cmdline.  For example:

	grub2-editenv /boot/grub2/grubenv set kernelopts="root=UUID=96fa7ba7-5229-4f32-a9d3-849404febb0e ro crashkernel=auto biosdevname=0 ip=9.114.227.82::9.114.224.1:22:jelly.pok.stglabs.ibm.com:net0:none:9.12.18.2 rd.neednet=1 rd.shell rd.debug log_buf_len=1M "

#### Network 

	ip=9.114.227.82::9.114.224.1:22:jelly.pok.stglabs.ibm.com:net0:none:9.12.18.2

#### Debug

	rd.neednet=1 rd.shell rd.debug log_buf_len=1M
