#!/bin/bash -x

################################################################################
#                                                                              #
# SPDX-License-Identifier: Apache-2.0                                          #
#                                                                              #
# hpcs-for-luks-rootfs-config.sh                                               #
#                                                                              #
# This script configures a secondary encrypted rootfs volume with a key        #
# wrapped and unwrapped by HPCS for LUKS, duplicates the primary rootfs data   #
# into it, and configures GRUB to boot it. It is written specifically for      #
# PowerVS, is provided as an example, and may not work as is in your           #
# environment.                                                                 #
#                                                                              #
# Assumptions:                                                                 #
#  - HPCS has been configured                                                  #
#  - An extra volume has been allocated and is mapped into /dev/mapper         #
#                                                                              #
# Copyright (C) 2024 IBM Corp.  All rights reserved.                           #
#                                                                              #
# Contributors:  George Wilson, Arnold Beilmann, Nayna Jain, and Sam Matzek    #
#                                                                              #
################################################################################


################################################################################
# Print the OS release number.                                                 #
################################################################################
os_release() {
	awk -F= '/^VERSION_ID/ { print gensub("\"", "", "g", $2) }' /etc/os-release
}

################################################################################
# Print the OS name and version                                                #
################################################################################
os_namever() {
	local NAME=$(awk -F'=' '/^NAME/ { print gensub("\"", "", "g", $2) }' /etc/os-release)
	local VERS=$(awk -F'=' '/^VERSION_ID/ { print gensub("\"", "", "g", $2) }' /etc/os-release)
	echo "$NAME" "$VERS"
}

################################################################################
# Search the mount table, find the root partition, and print the partition     #
# mounted on it.                                                               #
################################################################################
root_dm_part() {
	mount | awk '$3 == "/" { print $1; }'
}

################################################################################
# Print the first UUID associated with the input device.                       #
################################################################################
uuid_from_dev() {
	lsblk -n --output UUID $1 | head -1
}
 
################################################################################
# Search the mount table, find the dm partition mounted on root, and print the #
# underlying dm device.                                                        #
################################################################################
root_dm_dev() {
	mount | awk '$3 == "/" { print gensub("/(.*)/(.*)/(.*)p(.*)","/\\1/\\2/\\3" , "1", $1); }'
}

################################################################################
# Search /dev/mapper for a device that does not match either the input device  #
# or "control" and print the first one found.  Upon failure, exit.             #
################################################################################
spare_dm_dev() {
	local PART
	for PART in /dev/mapper/*; do
		if [[ ! ("$PART" =~ "$1" || "$PART" =~ "control") ]]; then
			echo $PART
			return
		fi
	done
	echo "No spare volume found for encrypted volume; terminating" 1>&2
	exit 1
}

################################################################################
# Return the IP address of the passed in network device.                       #
################################################################################
ip_addr() {
	ip -o -4 addr show dev $1 | awk '{ print gensub("(.*)/(.*)", "\\1", "1", $4); }'
}

################################################################################
# Return the netmask of the input network interface.                           #
################################################################################
ip_netmask() {
	local NETMASK_STR=$(ipcalc --netmask $(ip -o -4 addr show dev $1 | awk '{ print $4 }'))
	echo ${NETMASK_STR##NETMASK=}
}

################################################################################
# Return the gateway of the input network interface.                           #
################################################################################
ip_gateway() {
	ip -4 route show dev $1 | awk '/default/ { print $3 }'
}

################################################################################
# Return the first non-localhost DNS server in /etc/resolv.conf.               #
################################################################################
ip_dns() {
	#nmcli dev show $1 | awk '/DNS\[1\]/ { print $2 }'
	awk '/nameserver/ { if($2 !~ "^127") { print $2; exit;} }' </etc/resolv.conf
}

################################################################################
# Select a network interface: for now simply take the first one up.  Exit      #
# upon failure.                                                                #
################################################################################
select_if() {
	local IF=$(ip -o address show scope global up | awk 'FNR == 1 { print $2 }')
	if [ "$IF" == "" ]; then
		echo "No likely network interface found; terminating" 1>&2
		exit 1
	fi
	echo $IF
}

################################################################################
# Print a banner with hostname, OS name and release, and which volume booted.  #
################################################################################
print_banner() {
	local BANNER='
********************************************************************************
*                                                                              *
* Welcome to HOSTNAMEHOSTNAMEHOSTNAMEHOSTNAME                                  *
*                                                                              *
* Running RELEASEERELAESEERELEASEERELEASEE                                     *
*                                                                              *
* rootfs volume: ENCRYPTDENCRYPTDENCRYPTDENCRYPTD                              *
*                                                                              *
********************************************************************************
'
	local PAD="                                "
	local H_PADDED=${1}${PAD::${#PAD}-${#1}}
	local R_PADDED=${2}${PAD::${#PAD}-${#2}}
	local E_PADDED=${3}${PAD::${#PAD}-${#3}}
	echo "$BANNER" | sed "s/HOSTNAMEHOSTNAMEHOSTNAMEHOSTNAME/$H_PADDED/
                              s/RELEASEERELAESEERELEASEERELEASEE/$R_PADDED/
                              s/ENCRYPTDENCRYPTDENCRYPTDENCRYPTD/$E_PADDED/"
}

################################################################################
# Print hpcs-for-luks bootloader entry index or "none" of nonexistent.         #
################################################################################
hfl_ble_index() {
	local MAX=99
	local INDEX=0
	while [ $INDEX -lt $MAX ]; do
		OUTPUT=$(grubby --info $INDEX 2>&1)
		if echo $OUTPUT | grep -q "hpcs-for-luks"; then
			echo $INDEX
			return 0
		fi
		if echo $OUTPUT | grep -q "incorrect"; then
			echo 'none'
			return 1
		fi
	INDEX=$((INDEX+1))
	done
	echo 'none'
	return 1
}

################################################################################
################################################################################
##                                                                            ##
##                                Main                                        ##
##                                                                            ##
################################################################################
################################################################################

################################################################################
# Parse args                                                                   #
################################################################################

if [ "$1" == "-n" ]; then
	NOCLEANANDREBOOT=1
else
	NOCLEANANDREBOOT=0
fi


################################################################################
# Setup variables                                                              #
################################################################################

#
# Name of default variables script sourced in
#
# If the variables script exists, variables with the same name in it override
# values in the present script
#
export VAR_SCRIPT="/root/hpcs-for-luks-rootfs-config-vars.sh"

#
# Confidential inputs!
#
export api_key=""
export luks_pass=""

#
# VPEs for IAM and HPCS, HTTP proxy
#
export iam_vpe=""
export key_protect_vpe=""
export http_proxy_addr=""

#
# HPCS configuration data
#
export hpcs_region=""
export endpoint_url=""
export iam_endpoint_url=""
export service_instance_id=""
export hpcs_key_name=""

#
# Network configuration data
#
export mgmt_device=$(select_if)
export vm_ip=$(ip_addr $mgmt_device)
export vm_netmask=$(ip_netmask $mgmt_device)
export vm_gw=$(ip_gateway $mgmt_device)
#export vm_nameserver=$(ip_dns)
export vm_nameserver=""
export hostname=$(hostname)

#
# Assign default values from sourced script if it exists
#
if [ -f "${VAR_SCRIPT}" ]; then
	. "${VAR_SCRIPT}"
fi

#
# HTTP(S) proxy configuration
#
if [ "${http_proxy_addr}" != "" ]; then
	export http_proxy=http://${http_proxy_addr}
	export https_proxy=http://${http_proxy_addr}
	export HTTP_PROXY=http://${http_proxy_addr}
	export HTTPS_PROXY=http://${http_proxy_addr}

	#
	# Add these entries to /etc/bashrc to persist proxy setup
	#
	echo "export http_proxy=http://${http_proxy_addr}" >> /etc/bashrc
	echo "export https_proxy=http://${http_proxy_addr}" >> /etc/bashrc
	echo "export HTTP_PROXY=http://${http_proxy_addr}" >> /etc/bashrc
	echo "export HTTPS_PROXY=http://${http_proxy_addr}" >> /etc/bashrc
fi

################################################################################
# Install                                                                      #
################################################################################

#
# Install prerequisite packages
#
dnf install -y cryptsetup python3 python3-cryptography python3-pip wget
if [ $? -ne 0 ]; then
	echo "dnf install of prerequisite packages failed" 1>&2
	exit 1
fi

#
# Install the Python keyprotect prerequisite
#
pip3 install keyprotect 
if [ $? -ne 0 ]; then
	echo "pip install of keyprotect failed" 1>&2
	exit 1
fi

#
# Fetch, check, and install HPCS for LUKS
#
#RPM_URL="https://github.com/IBM/hyperprotect/raw/main/hpcs-for-luks/hpcs-for-luks-2.2-1.el9.noarch.rpm"
RPM_URL="https://github.com/gcwilson/hyperprotect/raw/hpcs-for-luks-v2.2/hpcs-for-luks/hpcs-for-luks-2.2-1.el9.noarch.rpm"
RPM_HASH="a4cc4a352ed3fea1c8634322b8776dcbae14f91e51b00525da8eb52d2c4c7fd2"
RPM_NAME=$(basename $RPM_URL)

wget $RPM_URL
if [ $? -ne 0 ]; then
	echo "wget of HPCS for LUKS RPM failed" 1>&2
	exit 1
fi

checksum=$(sha256sum $RPM_NAME | awk '{print $1}')
if [ $checksum  != $RPM_HASH ]; then
	echo "HPCS for LUKS checksum verification failed" 1>&2
	exit 1
fi

rpm -i $RPM_NAME
if [ $? -ne 0 ]; then
	echo "Install of HPCS for LUKS RPM failed" 1>&2
	exit 1
fi

#
# Fixup hpcs-for-luks for RHEL 8.6
#
if [ "$(os_release)" == "8.6" ]; then
	sed -i 's/\$SYSTEMCTL/systemctl/' /usr/lib/dracut/modules.d/95hpcs-for-luks/module-setup.sh
fi

################################################################################
# Prepare encrypted volume                                                     #
################################################################################

#
# Locate the device to encrypt
#
wwn_path=$(spare_dm_dev $(root_dm_dev))
export wwn=${wwn_path##/dev/mapper/}
# GCW: Is this necessary?  Why can't the /dev/mapper device be used directly?
#device=$(multipath -ll | grep -i -B 1 $wwn | grep dm- | awk '{print "/dev/"$2}' | tr '\n' ' ')
device=$wwn_path
echo "device to encrypt:: ${device}"

#
# Create a physical volume on the selected device
# GCW:  Why?  We aren't using LVM here (yet).
#
pvcreate $device

#
# LUKS format the selected device and open it mapped as /dev/mapper/root
#
echo -n "${luks_pass}" | cryptsetup luksFormat --type luks2 ${device} -
if [ $? -ne 0 ]; then
	echo "cryptsetup luksFormat failed" 1>&2
	exit 1
fi
echo -n "${luks_pass}" | cryptsetup open ${device} root -
if [ $? -ne 0 ]; then
	echo "cryptsetup open failed" 1>&2
	exit 1
fi

#
# Format the encrypted device with a filesystem
#
mkfs.xfs /dev/mapper/root
if [ $? -ne 0 ]; then
	echo "mkfs.xfs failed" 1>&2
	exit 1
fi

################################################################################
# Configure HPCS for LUKS                                                      #
################################################################################

#
# Add data to /etc/hpcs-for-luks.ini 
#
mv /etc/hpcs-for-luks.ini /etc/hpcs-for-luks.ini.bak
echo "[KP]" > /etc/hpcs-for-luks.ini
echo "region = ${hpcs_region}" >> /etc/hpcs-for-luks.ini
echo "endpoint_url = ${endpoint_url}" >> /etc/hpcs-for-luks.ini
echo "iam_endpoint_url = ${iam_endpoint_url}" >> /etc/hpcs-for-luks.ini
echo "service_instance_id = ${service_instance_id}" >> /etc/hpcs-for-luks.ini
echo "api_key = ${api_key}" >> /etc/hpcs-for-luks.ini
cat /etc/hpcs-for-luks.ini

#
# Configure default CRK UUID in /etc/hpcs-for-luks.ini
#
#hpcs-for-luks create --crk --gen --name ${hpcs_key_name}
crk_uuid=$(hpcs-for-luks list | grep -m 1 ${hpcs_key_name} | awk '{print $1}')
echo "default_crk_uuid = ${crk_uuid}" >> /etc/hpcs-for-luks.ini
cat /etc/hpcs-for-luks.ini

################################################################################
# Setup encrypted volume to use HPCS-wrapped volume key in keyring             #
################################################################################

#
# Wrap the LUKS passphrase with HPCS
#
echo -n "${luks_pass}" | hpcs-for-luks wrap > /var/lib/hpcs-for-luks/user/luks:root
if [ $? -ne 0 ]; then
	echo "hpcs-for-luks wrap failed" 1>&2
	exit 1
fi

#
# Add the keyring token with description matching keyring to LUKS header
#
cryptsetup token add ${device} --key-description luks:root
if [ $? -ne 0 ]; then
	echo "cryptsetup token add failed" 1>&2
	exit 1
fi

#
# Enable the HPCS for LUKS wipe service to remove roofs volume passphrase after
# use
#
systemctl enable hpcs-for-luks-wipe
if [ $? -ne 0 ]; then
	echo "systemctl enable hpcs-for-luks-wipe failed" 1>&2
	exit 1
fi

#
# Test cycle - should work without asking for password
#
cryptsetup close root
hpcs-for-luks process
cryptsetup open ${device} root
if [ $? -ne 0 ]; then
	echo "cryptsetup open failed" 1>&2
	exit 1
fi

################################################################################
# Setup encrypted volume contents                                              #
################################################################################

#
# Mount the encrypted rootfs and rsync the unencrypted rootfs contents to it
#
mkdir /mnt/encryptedroot
if [ $? -ne 0 ]; then
	echo "mkdir for encrypted rootfs failed" 1>&2
	exit 1
fi
mount /dev/mapper/root /mnt/encryptedroot
if [ $? -ne 0 ]; then
	echo "mount of encrypted rootfs failed" 1>&2
	exit 1
fi
#
# Handle RHEL 8.8 "ghost" file
#
if [[ $(os_release) =~ ^8 ]]; then
	> /setup.sh
fi
rsync -a --info=progress2 --exclude='/dev/*' --exclude='/tmp/*' --exclude='/run/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/boot/*' --exclude='/mnt/encryptedroot' / /mnt/encryptedroot
if [ $? -ne 0 ]; then
	echo "rsync of unencrypted rootfs to encrypted rootfs failed failed" 1>&2
	exit 1
fi

#
# Force SELinux relabel of encrypted rootfs during first boot
#
touch /mnt/encryptedroot/.autorelabel

#
# Get encrypted rootfs volume UUID
#
#if [[ $(os_release) =~ ^9 ]]; then
#	disk_uuid=$(lsblk -f | grep -m 1 crypto_LUKS | awk '{print $4}')
#else
#	disk_uuid=$(lsblk -f | grep -m 1 crypto_LUKS | awk '{print $3}')
#fi
disk_uuid=$(uuid_from_dev $wwn_path)
echo "disk_uuid: ${disk_uuid}"

#
# Generate crypttab
#
echo "root UUID=${disk_uuid} none luks,_netdev" > /mnt/encryptedroot/etc/crypttab

#
# Generate fstab
#
# On the the unified encrypted volume, the unencrypted volume is mounted on /mnt
# and /mnt/boot is bind mounted on /boot to allow changes to it in the same
# manner as when booted on the unencrypted volume.
#
echo "/dev/mapper/root                              /     xfs  defaults 0 1" > /mnt/encryptedroot/etc/fstab
echo "/swapfile                                     swap  swap defaults 0 0" >> /mnt/encryptedroot/etc/fstab
if mountpoint -q /boot; then
	echo "LABEL=boot                            /boot xfs  defaults 0 1" >> /mnt/encryptedroot/etc/fstab
else
	echo "UUID=$(uuid_from_dev $(root_dm_part)) /mnt  xfs  defaults 0 1" >> /mnt/encryptedroot/etc/fstab
	echo "/mnt/boot                             /boot -    bind     0 0" >> /mnt/encryptedroot/etc/fstab
fi

#
# Add motds to show which volume booted
#
print_banner $hostname "$(os_namever)" Unencrypted > /etc/motd
print_banner $hostname "$(os_namever)" Encrypted >   /mnt/encryptedroot/etc/motd

################################################################################
# Setup encrypted volume boot configuration                                    #
################################################################################

#
# Fixup /etc/default/grub and rebuild grub.cfg
#
# - rd.debug is too noisy so remove it.
# - GRUB_TIMEOUT needs to be long enough to see the menu.
# - We want GRUB_DISABLE_OS_PROBER because os-prober generates lots of duplicate
#   entries directly in grub.cfg - seems to be multipath.
#
sed -i '
s/rd\.debug //
/GRUB_TIMEOUT.*/d
/GRUB_DISABLE_OS_PROBER.*/d
$ a \
GRUB_TIMEOUT=20\
GRUB_DISABLE_OS_PROBER=true' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg

#
# Modify initramfs
#
INITIAL_UMASK=`umask`
umask 022

echo 'force_drivers+=" dm-multipath "' >/etc/dracut.conf.d/10-mp.conf
dracut --regenerate-all --force
if [ $? -ne 0 ]; then
	echo "dracut rebuild to add multipath driver to all images failed" 1>&2
	exit 1
fi

# We want to persist the Dracut configuration in case the initramfs gets rebuilt subsequently
for DRACUT_MODULE in multipath hpcs-for-luks crypt ifcfg network network-manager url-lib; do
	echo "add_dracutmodules+=\" $DRACUT_MODULE \"" > /etc/dracut.conf.d/${DRACUT_MODULE}.conf
done
echo "install_items+=\" /sbin/cryptsetup /usr/lib/systemd/system/cryptsetup-pre.target \"" >> /etc/dracut.conf.d/crypt.conf
echo "install_items+=\" /etc/multipath /etc/multipath.conf \"" >> /etc/dracut.conf.d/multipath.conf

dracut --force --verbose
if [ $? -ne 0 ]; then
	echo "dracut rebuild to add HPCS for LUKS to 0th image failed" 1>&2
	exit 1
fi

umask $INITIAL_UMASK

#
# Get the kernel name, initrd name, and arguments to pass to grubby
#
kernel=$(grubby --info 0 | grep -m 1 kernel | grep -o '"[^"]\+"' | sed 's/"//g')
echo "kernel: ${kernel}"
initrd=$(grubby --info 0 | grep -m 1 initrd | grep -o '"[^"]\+"' | sed 's/"//g')
echo "initrd: ${initrd}"
args=$(grubby --info 0 | grep -m 1 args | grep -o '"[^"]\+"' | sed 's/"//g') 
args=$(echo $args | sed 's/rd\.debug//')
args="${args} rd.hpcs-for-luks rd.neednet=1 rd.auto=1 root=/dev/mapper/root rd.luks.uuid=${disk_uuid} rd.luks.name=${disk_uuid}=root ip=${vm_ip}::${vm_gw}:${vm_netmask}:${hostname}:${mgmt_device}:none nameserver=${vm_nameserver}"
#
# Needed for "regular" 9.2 image but not for "other" image :-/
#
#if [[ $(os_release) =~ ^9 ]]; then
#	args="${args} net.ifnames=0 biosdevname=0"
#fi
echo "args: ${args}"

#
# Add the boot entry to the GRUB config
#
grubby --add-kernel="${kernel}" --title="Boot from encrypted root" --initrd="${initrd}" --args="${args}"
if [ $? -ne 0 ]; then
	echo "grubby 1 failed" 1>&2
	exit 1
fi

#
# Set the default bootloader entry to the entry with hpcs-for-luks in it if it
# exists or to 0 if it doesn't.
#
BLE=$(hfl_ble_index)
if [ "$BLE" != "none" ]; then
	grubby --set-default $BLE
else
	echo "Attention: Bootloader entry with hpcs-for-luks doesn't exist; defaulting to index 0" 1>&2
	grubby --set-default 0
fi
if [ $? -ne 0 ]; then
	echo "grubby 2 failed" 1>&2
	exit 1
fi

#
# Duplicate the GRUB environment variable space to the UEFI dir - should be
# unnecessary on Power
#
cp /boot/grub2/grubenv /boot/efi/EFI/redhat/

#
# Clean up vars file and reboot unless directed not to
#
if [ $NOCLEANANDREBOOT -ne 1 ]; then
	rm -f ${VAR_SCRIPT}
	sync
	umount /mnt/encryptedroot
	sleep 1
	shutdown -r now
fi
