#!/bin/bash -x

################################################################################
#                                                                              #
# SPDX-License-Identifier: Apache-2.0                                          #
#                                                                              #
# hpcs-for-luks-rootfs-config.sh                                               #
#                                                                              #
# This script configures a secondary device with PReP partition, bootfs        #
# partition, and rootfs partition, creates an encrypted rootfs volume with a   #
# key wrapped and unwrapped by HPCS for LUKS, duplicates the primary rootfs    #
# data into it, and configures GRUB to boot it. It is written specifically for #
# PowerVS, is provided as an example, and likely will not work in your         #
# environment as is.                                                           #
#                                                                              #
# The script is very brittle with respect to the environment and makes a       #
# number of assumptions.  Some are documented below.                           #
#                                                                              #
# Major Assumptions:                                                           #
#  - HPCS has been configured and a CRK generated and referenced in the        #
#    script.                                                                   #
#  - The storage devices are multipath and mapped into /dev/mapper.            #
#  - An extra storage device has been allocated that is exactly the same 100G  #
#    size as the originally provisioned device and is mapped into /dev/mapper. #
#  - The first device that the root partition does not reside on is the right  #
#    one for the new PReP, bootfs, and encrypted rootfs.  Allocate the extra   #
#    storage accordingly.                                                      #
#  - The script will be executed only once; it will fail if executed a         #
#    second time.                                                              #
#  - The first network interface is the correct one to use.  Allocate the      #
#    network interfaces accordingly.                                           #
#  - The nameserver must be configured manually in the script; it cannot       #
#    be determined automatically for resolving the HPCS host in PowerVS.       #
#                                                                              #
# Notes:                                                                       #
#  - Script variable overrides can be placed in the                            #
#    /root/hpcs-for-luks-rootfs-config-vars.sh script                          #
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
	mount | awk '$3 == "/" { print gensub("/(.*)/(.*)/(.*)(p*)(.)","/\\1/\\2/\\3" , "1", $1); }'
}

################################################################################
# Search /dev/mapper for a device that does not match either the input device  #
# or "control" and print the first one found.  Upon failure, exit.             #
# $1: Device to filter from /dev/mapper (presumably rootfs partition device)   #
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
# Print random disk ID of 8 hex digits.                                        #
################################################################################
gen_labelid() {
	dd if=/dev/urandom bs=4 count=1  2>/dev/null | hexdump -e '"%x"'
}

################################################################################
# Add partitions to the new device.  Assume sizes for now - we can             #
# calculate them later if necessary.                                           #
# $1: Device upon which to create partitions                                   #
################################################################################
create_new_dev_parts() {
	local P_SEP
	cat <<__END > /tmp/parttable.txt
label: dos
label-id: 0xNEWLABEL
device: NEWDEV
unit: sectors
sector-size: 512

NEWDEV1 : start=        2048, size=        8192, type=41, bootable
NEWDEV2 : start=       10240, size=     1024000, type=83
NEWDEV3 : start=     1034240, size=   208680927, type=83
__END
	sed -i "s/NEWLABEL/$(gen_labelid)/" /tmp/parttable.txt
	if [[ ${1: -1} =~ [0-9] ]]; then
		P_SEP="p"
	else
		P_SEP=""
	fi
	sed -i "s-NEWDEV-${1}${P_SEP}-g" /tmp/parttable.txt
	sfdisk "$1" </tmp/parttable.txt
	if [ $? != 0 ]; then
		echo "sfdisk $1 failed" 1>&2
		exit 1
	fi
	rm -f /tmp/parttable.txt
}

################################################################################
# Wait for partition block device to appear.                                   #
# $1: Device for which to wait                                                 #
################################################################################
waitfor_blockdev() {
	local MAX=10
	local INTERVAL=1
	local COUNT=0
	while [ $COUNT -lt $MAX ]; do
		if [ -b "$1" ]; then
			return 0
		fi
		sleep $INTERVAL
	done
	echo "waitfor_blockdev $1 timed out" 1>&2
	return 1
}

################################################################################
# Create properly formed partition device name from device and number.         #
# If the last char is a number, a "p" must be added between the base device    #
# and the partition number; if not, a "p" must not be added.                   #
# $1: Device                                                                   #
# $2: Partition number                                                         #
################################################################################
partition_name() {
	local P_SEP
	if [[ ${1: -1} =~ [0-9] ]]; then
		P_SEP="p"
	else
		P_SEP=""
	fi
	echo ${1}${P_SEP}${2}
}

################################################################################
################################################################################
##                                                                            ##
##                                Main                                        ##
##                                                                            ##
################################################################################
################################################################################

################################################################################
# Parse args.                                                                  #
################################################################################

if [ "$1" == "-n" ]; then
	NOCLEANANDREBOOT=1
else
	NOCLEANANDREBOOT=0
fi


################################################################################
# Setup variables.                                                             #
################################################################################

#
# Name of default variables script sourced in.
#
# If the variables script exists, variables with the same name in it override
# values in the present script.
#
export VAR_SCRIPT="/root/hpcs-for-luks-rootfs-config-vars.sh"

#
# Confidential inputs!
#
export API_KEY=""
export LUKS_PASS=""

#
# VPEs for IAM and HPCS, HTTP proxy.
#
export iam_vpe="10.20.20.5"
export key_protect_vpe="10.20.20.6"
export HTTP_PROXY_ADDR=""

#
# HPCS configuration data.
#
export HPCS_REGION=""
export ENDPOINT_URL=""
export IAM_ENDPOINT_URL=""
export SERVICE_INSTANCE_ID=""
export HPCS_KEY_NAME=""

#
# Network configuration data.
#
export MGMT_IF=$(select_if)
export VM_IP=$(ip_addr $MGMT_IF)
export VM_NETMASK=$(ip_netmask $MGMT_IF)
export VM_GW=$(ip_gateway $MGMT_IF)
#export VM_NAMESERVER=$(ip_dns)
export VM_NAMESERVER=""
export HOSTNAME=$(hostname)

#
# Assign default values from sourced script if it exists.
#
if [ -f "${VAR_SCRIPT}" ]; then
	. "${VAR_SCRIPT}"
fi

#
# HTTP(S) proxy configuration
#
if [ "${HTTP_PROXY_ADDR}" != "" ]; then
	export http_proxy=http://${HTTP_PROXY_ADDR}
	export https_proxy=http://${HTTP_PROXY_ADDR}
	export HTTP_PROXY=http://${HTTP_PROXY_ADDR}
	export HTTPS_PROXY=http://${HTTP_PROXY_ADDR}

	#
	# Add these entries to /etc/bashrc to persist proxy setup
	#
	echo "export http_proxy=http://${HTTP_PROXY_ADDR}" >> /etc/bashrc
	echo "export https_proxy=http://${HTTP_PROXY_ADDR}" >> /etc/bashrc
	echo "export HTTP_PROXY=http://${HTTP_PROXY_ADDR}" >> /etc/bashrc
	echo "export HTTPS_PROXY=http://${HTTP_PROXY_ADDR}" >> /etc/bashrc
fi

################################################################################
# Install.                                                                     #
################################################################################

#
# Install prerequisite packages.
#
dnf install -y cryptsetup powerpc-utils python3 python3-cryptography python3-pip wget
if [ $? -ne 0 ]; then
	echo "dnf install of prerequisite packages failed" 1>&2
	exit 1
fi

#
# Install the Python keyprotect prerequisite.
#
pip3 install keyprotect 
if [ $? -ne 0 ]; then
	echo "pip install of keyprotect failed" 1>&2
	exit 1
fi

#
# Fetch, check, and install HPCS for LUKS.
#
#RPM_URL="https://github.com/gcwilson/hyperprotect/raw/hpcs-for-luks-v2.2/hpcs-for-luks/hpcs-for-luks-2.2-1.el9.noarch.rpm"
RPM_URL="https://github.com/IBM/hyperprotect/raw/main/hpcs-for-luks/hpcs-for-luks-2.6-1.el9.noarch.rpm"
RPM_HASH="1c688bab71f7f0ee17c4631eb5fbe3fab4490971b2cf5e25b7e2dfb8a9bec567"
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
# Prepare encrypted volume.                                                    #
################################################################################

#
# Locate the device to encrypt.
#
OLD_DEVICE=$(root_dm_dev)
WWN_PATH=$(spare_dm_dev ${OLD_DEVICE})
export WWN=${WWN_PATH##/dev/mapper/}
# GCW: Is this necessary?  Why can't the /dev/mapper device be used directly?
#NEW_DEVICE=$(multipath -ll | grep -i -B 1 $WWN | grep dm- | awk '{print "/dev/"$2}' | tr '\n' ' ')
NEW_DEVICE=${WWN_PATH}
echo "device to encrypt:: ${NEW_DEVICE}"

#
# Set variables for the partitions.
#
OLD_PREP_PART=$(partition_name ${OLD_DEVICE} 1)
OLD_BOOT_PART=$(partition_name ${OLD_DEVICE} 2)
OLD_ROOT_PART=$(partition_name ${OLD_DEVICE} 3)
NEW_PREP_PART=$(partition_name ${NEW_DEVICE} 1)
NEW_BOOT_PART=$(partition_name ${NEW_DEVICE} 2)
ENCROOT_PART=$(partition_name ${NEW_DEVICE} 3)

#
# Create partitions on the selected device.
#
create_new_dev_parts ${NEW_DEVICE}
if [ $? -ne 0 ]; then
	echo "create_new_dev_parts failed" 1>&2
	exit 1
fi

#
#  Wait for PReP partition device to appear.
#
waitfor_blockdev "$NEW_PREP_PART"

#
# Copy over PReP partition.
#
dd if=${OLD_PREP_PART} of=${NEW_PREP_PART}
if [ $? -ne 0 ]; then
	echo "dd of old to new PReP partition failed" 1>&2
	exit 1
fi

#
# Format boot partition with a filesystem.
#
mkfs.xfs ${NEW_BOOT_PART}

#
# LUKS format the selected device and open it mapped as /dev/mapper/root.
#
echo -n "${LUKS_PASS}" | cryptsetup luksFormat --type luks2 ${ENCROOT_PART} -
if [ $? -ne 0 ]; then
	echo "cryptsetup luksFormat failed" 1>&2
	exit 1
fi
echo -n "${LUKS_PASS}" | cryptsetup open ${ENCROOT_PART} root -
if [ $? -ne 0 ]; then
	echo "cryptsetup open failed" 1>&2
	exit 1
fi

#
# Format the encrypted device with a filesystem.
#
mkfs.xfs /dev/mapper/root
if [ $? -ne 0 ]; then
	echo "mkfs.xfs failed" 1>&2
	exit 1
fi

################################################################################
# Configure HPCS for LUKS.                                                     #
################################################################################

#
# Add data to /etc/hpcs-for-luks.ini.
#
mv /etc/hpcs-for-luks.ini /etc/hpcs-for-luks.ini.bak
echo "[KP]" > /etc/hpcs-for-luks.ini
echo "region = ${HPCS_REGION}" >> /etc/hpcs-for-luks.ini
echo "endpoint_url = ${ENDPOINT_URL}" >> /etc/hpcs-for-luks.ini
echo "iam_endpoint_url = ${IAM_ENDPOINT_URL}" >> /etc/hpcs-for-luks.ini
echo "service_instance_id = ${SERVICE_INSTANCE_ID}" >> /etc/hpcs-for-luks.ini
echo "api_key = ${API_KEY}" >> /etc/hpcs-for-luks.ini
cat /etc/hpcs-for-luks.ini

#
# Configure default CRK UUID in /etc/hpcs-for-luks.ini.
#
#hpcs-for-luks create --crk --gen --name ${HPCS_KEY_NAME}
CRK_UUID=$(hpcs-for-luks list | grep -m 1 ${HPCS_KEY_NAME} | awk '{print $1}')
echo "default_crk_uuid = ${CRK_UUID}" >> /etc/hpcs-for-luks.ini
cat /etc/hpcs-for-luks.ini

################################################################################
# Setup encrypted volume to use HPCS-wrapped volume key in keyring.            #
################################################################################

#
# Wrap the LUKS passphrase with HPCS.
#
echo -n "${LUKS_PASS}" | hpcs-for-luks wrap > /var/lib/hpcs-for-luks/user/luks:root
if [ $? -ne 0 ]; then
	echo "hpcs-for-luks wrap failed" 1>&2
	exit 1
fi

#
# Add the keyring token with description matching keyring to LUKS header.
#
cryptsetup token add ${ENCROOT_PART} --key-description luks:root
if [ $? -ne 0 ]; then
	echo "cryptsetup token add failed" 1>&2
	exit 1
fi

#
# Enable the HPCS for LUKS wipe service to remove roofs volume passphrase after
# use.
#
systemctl enable hpcs-for-luks-wipe
if [ $? -ne 0 ]; then
	echo "systemctl enable hpcs-for-luks-wipe failed" 1>&2
	exit 1
fi

#
# Test cycle - should work without asking for password.
#
cryptsetup close root
hpcs-for-luks process
cryptsetup open ${ENCROOT_PART} root
if [ $? -ne 0 ]; then
	echo "cryptsetup open failed" 1>&2
	exit 1
fi

################################################################################
# Get encrypted rootfs volume UUID.                                            *
################################################################################
ENC_ROOT_PART_UUID=$(uuid_from_dev ${ENCROOT_PART})
echo "Encrypted partition UUID: ${ENC_ROOT_PART_UUID}"

################################################################################
# Setup encrypted volume boot configuration.                                   #
################################################################################

#
# Fixup /etc/default/grub and rebuild grub.cfg.
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

# We want to persist the Dracut configuration in case the initramfs gets rebuilt subsequently.
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
# Get the kernel name, initrd name, and arguments to pass to grubby.
#
KERNEL=$(grubby --info 0 | grep -m 1 kernel | grep -o '"[^"]\+"' | sed 's/"//g')
echo "kernel: ${KERNEL}"
INITRD=$(grubby --info 0 | grep -m 1 initrd | grep -o '"[^"]\+"' | sed 's/"//g')
echo "initrd: ${INITRD}"
BOOT_ARGS=$(grubby --info 0 | grep -m 1 args | grep -o '"[^"]\+"' | sed 's/"//g') 
BOOT_ARGS=$(echo ${ARGS} | sed 's/rd\.debug//')
BOOT_ARGS="${BOOT_ARGS} rd.hpcs-for-luks rd.neednet=1 rd.auto=1 root=/dev/mapper/root rd.luks.uuid=${ENC_ROOT_PART_UUID} rd.luks.name=${ENC_ROOT_PART_UUID}=root ip=${VM_IP}::${VM_GW}:${VM_NETMASK}:${HOSTNAME}:${MGMT_IF}:none nameserver=${VM_NAMESERVER} proxy=${HTTP_PROXY_ADDR}"

#
# Needed for "regular" 9.2 image but not for "other" image :-/
#
#if [[ $(os_release) =~ ^9 ]]; then
#	BOOT_ARGS="${BOOT_ARGS} net.ifnames=0 biosdevname=0"
#fi
echo "args: ${BOOT_ARGS}"

#
# Add the boot entry to the GRUB config.
#
grubby --add-kernel="${KERNEL}" --title="Encrypted root" --initrd="${INITRD}" --args="${BOOT_ARGS}"
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
# unnecessary on Power.
#
cp /boot/grub2/grubenv /boot/efi/EFI/redhat/

################################################################################
# Setup encrypted volume contents.                                             #
################################################################################

#
# Created encrypted root mountpoint.
#
mkdir /mnt/encryptedroot
if [ $? -ne 0 ]; then
	echo "mkdir for encrypted rootfs failed" 1>&2
	exit 1
fi

#
# Mount encrypted root.
#
mount /dev/mapper/root /mnt/encryptedroot
if [ $? -ne 0 ]; then
	echo "mount of encrypted rootfs failed" 1>&2
	exit 1
fi

#
# Make boot dir on encrypted root.
#
mkdir /mnt/encryptedroot/boot

#
# Mount boot partition on encrypted root boot dir.
#
mount ${NEW_BOOT_PART} /mnt/encryptedroot/boot

#
# Handle RHEL 8.8 "ghost" file.
#
if [[ $(os_release) =~ ^8 ]]; then
	> /setup.sh
fi

#
# Rsync old to new fs's.
#
rsync -a --info=progress2 --exclude='/dev/*' --exclude='/tmp/*' --exclude='/run/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/mnt/encryptedroot' / /mnt/encryptedroot
if [ $? -ne 0 ]; then
	echo "rsync of unencrypted rootfs to encrypted rootfs failed" 1>&2
	exit 1
fi

#
# Force SELinux relabel of encrypted rootfs during first boot.
#
touch /mnt/encryptedroot/.autorelabel

################################################################################
# Do encrypted-volume specific configuration not to be rsync'd.                #
################################################################################

#
# Generate crypttab.
#
echo "root UUID=${ENC_ROOT_PART_UUID} none luks,_netdev" > /mnt/encryptedroot/etc/crypttab

#
# Generate fstab.
#
# On the the unified encrypted volume, the unencrypted volume is mounted on /mnt
# and /mnt/boot is bind mounted on /boot to allow changes to it in the same
# manner as when booted on the unencrypted volume.
#
echo "/dev/mapper/root                              /     xfs  defaults 0 1" > /mnt/encryptedroot/etc/fstab
echo "/swapfile                                     swap  swap defaults 0 0" >> /mnt/encryptedroot/etc/fstab
echo "UUID=$(uuid_from_dev ${NEW_BOOT_PART})        /boot xfs  defaults 0 1" >> /mnt/encryptedroot/etc/fstab

#
# Add motds to show which volume booted.
#
print_banner $HOSTNAME "$(os_namever)" Unencrypted > /etc/motd
print_banner $HOSTNAME "$(os_namever)" Encrypted >   /mnt/encryptedroot/etc/motd

#
# Change boot device to the secondary device.
#
OF_PATH=$(ofpathname "${WWN_PATH}")
if [ $? -ne 0 ]; then
	echo "conversion of ${WWN_PATH} to OF pathname failed" 1>&2
	exit 1
fi
nvram --update-config "boot-device=${OF_PATH}"
if [ $? -ne 0 ]; then
	echo "nvram --update-config "boot-device=${OF_PATH}" failed" 1>&2
	exit 1
fi

#
# Fixup GRUB search UUIDs for boot parition.
#
sed -i "s/$(uuid_from_dev ${OLD_BOOT_PART})/$(uuid_from_dev ${NEW_BOOT_PART})/g" /mnt/encryptedroot/boot/grub2/grub.cfg
if [ $? -ne 0 ]; then
	echo "sed to fixup GRUB search UUIDs failed" 1>&2
	exit 1
fi

#
# Add a device to the BLE title to show chosen device.
#
for F in /mnt/encryptedroot/boot/loader/entries/*; do
	sed -i "s/Encrypted root/Encrypted root via ${WWN}/" $F
done

#
# Clean up vars file and reboot unless directed not to.
#
if [ $NOCLEANANDREBOOT -ne 1 ]; then
	rm -f ${VAR_SCRIPT}
	sync
	umount /mnt/encryptedroot/boot
	umount /mnt/encryptedroot
	sleep 1
	shutdown -r now
fi
