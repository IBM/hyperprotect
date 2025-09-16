# Configuring HPVS-Onpremises from scratch, with RedHat
by [Sandeep Batta](mailto:sbatta@us.ibm.com), [Abhiram Kulkarni](abhiramk@in.ibm.com), [Peter Szmrecsanyi](mailto:peter.sz@ibm.com), [Sowmya Parvathi](mailto:sowparva@in.ibm.com)

[Hyper Protect Services](https://www.ibm.com/products/hyper-protect) uses [IBM Secure Execution for Linux (SEL)](https://www.ibm.com/docs/en/linux-on-systems?topic=virtualization-introducing-secure-execution-linux) to create a "Confidential Computing" enclave where sensitive workloads can be deployed with the technical assurance that the entire compute lifecycle will be protected. While solutions for protecting `data-at-rest` and `data-in-motion` are well known, the concept of protecting `data-in-use` from a bad actor, needs to become the focus of an overall data protection strategy.

A Confidential Computing enclave is like a Secure Compartmented Information Facility (SCIF), as shown in Figure-1, is commonly used in the national-security context, to discuss confidential / top-secret documents or strategy. The simple requirement is to make sure, "What happens in a SCIF, remains in a SCIF" 

![HPVS-SCIF](pictures/hpvs-scif.jpg)

This tutorial provides additional insight into official documentation on [Setting up and configuring IBM Hyper Protect Container Runtime](https://www.ibm.com/docs/en/hpcr/1.1.x?topic=runtime-setting-up-configuring-hyper-protect-container), to avoid going back and forth between different sets of documentations.


## Pre-requisites
- Access to a RHEL LPAR on a LinuxONE with `sudo` access. The LinuxONE must have Secure Execution Enabled with `Feature Code 115`
- Access to [IBM Passport Advantage](https://www-01.ibm.com/software/passportadvantage/pao_customer.html), to download HPVS image
- Access to a container image of the `workload` that will run inside the Hyper Protect Confidential Container Runtime, for example `Vault`

*Notes*: 
- For detailed HW requirements, check [HPCR System Requirements](https://www.ibm.com/docs/en/hpcr/1.1.x?topic=runtime-system-requirements)
- For details on downloading HPVS image, check [Downloadng HPCR image](https://www.ibm.com/docs/en/hpvs/2.2.x?topic=servers-downloading-hyper-protect-container-runtime-image)

## Step 1. Confirm "Secure Execution" is enabled
Logon to the RHEL LPAR and enter the following command:
```
virt-host-validate
```
If a WARNING is displayed for "Secure Execution", 
```
cp /etc/zipl.conf /etc/zipl.conf.orig
echo "prot_virt=1" >> /etc/zipl.conf
zipl -V
reboot
```
Now if you run `virt-host-validate`, you should see:
```
QEMU: Checking for secure guest support                                    : PASS
```

## Step 2. Prepare the environment
- Install required packages
```
dnf install genisoimage curl ca-certificates  
dnf install net-tools podman rsyslog-gnutls guestfs-tools
dnf install libvirt libvirt-daemon libvirt-daemon-driver-qemu libvirt-daemon-config-network libvirt-daemon-kvm
dnf install expect qemu-kvm qemu-img
dnf install virt-install virt-win-reg
dnf install -y postgresql-server postgresql
dnf upgrade -y
dnf upgrade NetworkManager
```
- Create the required directories and files
```
mkdir -p /opt/hpcr-files
mkdir -p /var/lib/libvirt/images/hpcr
mkdir -p /var/lib/libvirt/storage
mkdir -p /var/lib/libvirt/overlay
```
- Configure a SYSLOG server to receive secure logging information from HPVS guests (link to [doc](https://www.ibm.com/docs/en/hpvs/2.2.x?topic=servers-logging-hyper-protect-virtual#syslog))

## Step 3. Download the HPVS bundle
1. Logon to [IBM Passport Advantage](https://www-01.ibm.com/software/passportadvantage/pao_customer.html)
1. Navigate to **My Programs** and select **IBM  Hyper Protect Container Runtime**
1. Download the latest version. The name of the downloaded file will be something like `IBM_HPCR_RHVS_v1.1_EN.tar.gz`
1. Upload the HPVS Image to the LinuxONE RHEL LPAR like this:
   ```
   scp </path/to/IBM_HPCR_RHVS_v1.1_EN.tar.gz> <userid>@<linuxone-rhel-lpar>:/opt/hpcr-files
   ```  

## Step 4. Extract the HPVS image file
Logon to the LinuxONE RHEL LPAR and issue the following commands:
```
cd /opt/hpcr-files
gunzip IBM_HPCR_RHVS_v1.1_EN.tar.gz
tar -xvf IBM_HPCR_RHVS_v1.1_EN.tar
tar -xvzf M0SK4EN.tar.gz
cp images/ibm-hyper-protect-container-runtime-rhvs-1.1.0.qcow2 /var/lib/libvirt/images/hpcr
```

*Note*: The files names in your case might be different depending on the HPVS version you are working with

## Step 5. Create the contract parts
- Create the file `/var/lib/libvirt/images/hpcr/meta-data` with the following content
  ```
  local-hostname: myhost
  ```
- Create the file `/var/lib/libvirt/images/hpcr/vendor-data` with the following content
  ```
  #cloud-config
  users:
  - default
  ```
- Copy the [sample-env.yaml](configuration-files/hpvs-sample-env.yaml) file to `/var/lib/libvirt/images/hpcr/env.yaml`
- Edit the following entries in the `env.yaml` file replacing:
  1. `${HOSTNAME}` with the hostname or IP of the SYSLOG server on the network and change the port number if different
  2. `${CA}` with the YAML scallar equivalent of the CA certificate (for example: `server: "-----BEGIN CERTIFICATE-----\nMIIFCTCCAvECFEp7wJLz4jNStIsV..."`)
  3. `${CLIENT_CERTIFICATE}` with the YAML scallar equivalent of the client certificate
  4. `${CLIENT_PRIVATE_KEY}` with the YAML scallar equivalent of the client certificate PKCS8 key
- Copy the [sample-vault-workload.yaml](configuration-files/hpvs-sample-vault-workload.yaml) file to `/var/lib/libvirt/images/hpcr/workload.yaml`
- Edit the following entries in the `workload.yaml` file:
  1. `<us.icr.io/path-to-vault-image>`
  2. `<base64-vault-conf.hcl>`
  3. `<license-key>`
  4. `<us-icr-apikey>`
 
  *Notes*:
  - the sample workload.yaml file assumes that you have the Vault container image in [IBM Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_access). An `api-key` is required to access images in this registry.
  - for details on how to create a Vault Container Image, check `Part 1` of this tutorial [Deploying Vault in a confidential computing environment](https://developer.ibm.com/tutorials/awb-deploy-vault-securely-confidential-environment/)

## Step 6. Encrypt the contract file
- Export Environment Varaiables
  ```
  export WORKLOAD=/var/lib/libvirt/images/hpcr/workload.yaml
  export ENV=/var/lib/libvirt/images/hpcr/env.yaml
  export CONTRACT_KEY=/opt/hpcs-files/config/certs/ibm-hyper-protect-container-runtime-25.4.0-encrypt.crt
  export PASSWORD="$(openssl rand 32 | base64 -w0)"
  export ENCRYPTED_PASSWORD="$(echo -n "$PASSWORD" | base64 -d | openssl rsautl -encrypt -inkey $CONTRACT_KEY -certin | base64 -w0 )"
  ```
- Encrypt the `workload.yaml` file with the password generated above
  ```
  export ENCRYPTED_WORKLOAD="$(echo -n "$PASSWORD" | base64 -d | openssl enc -aes-256-cbc -pbkdf2 -pass stdin -in "$WORKLOAD" | base64 -w0)"
  ```
- Encrypt the `env.yaml` file with the password generated above
  ```
  export ENCRYPTED_ENV="$(echo -n "$PASSWORD" | base64 -d | openssl enc -aes-256-cbc -pbkdf2 -pass stdin -in "$ENV" | base64 -w0)"
  ```
- Create `user-data.yaml` file
  ```
  echo "hyper-protect-basic.${ENCRYPTED_PASSWORD}.${ENCRYPTED_ENV}" > /var/lib/libvirt/images/hpcr/user-data.yaml
  echo "hyper-protect-basic.${ENCRYPTED_PASSWORD}.${ENCRYPTED_WORKLOAD}" >> /var/lib/libvirt/images/hpcr/user-data.yaml
  ```

## Step 7. Generate ISO-init-disk
```
genisoimage -output /var/lib/libvirt/images/ciiso.iso -volid cidata -joliet -rock user-data meta-data vendor-data
```

## Step 8. Create the Data disk
- Copy [sample-pool.xml](configuration-files/hpvs-sample-pool.xml) to `/opt/hpcr-files/pool.xml` and issue the following commands:
  ```
  virsh pool-define pool.xml
  virsh pool-build storagedirpool
  virsh pool-start storagedirpool
  virsh vol-create-as storagedirpool datavolume 10G
  ```
- Copy [sample-kvm-domain.xml](configuration-files/hpvs-sample-hpcr.xml) to `/opt/hpcr-files/hpcr.xml`

## Step 9. Create the Network
- Copy [sample-pool.xml](configuration-files/hpvs-sample-network.xml) to `/opt/hpcr-files/network.xml`
- Update the network details in `network.xml` as it applies to your environment

## Step 10. Start HPCR
Issue the following commands to start the confidential computing environment:
```
virsh define hpcr.xml
virsh start hpcr --console
```

## Conclusion & Next Steps
Congratulations on going through the above process to bring up on-premises Hyper Protect Container Runtime (HPCR) on IBM Z LinuxONE. The suggested next step will be to bring up critical workloads that will provide data-in-use protection. The following blogs, tutorials and demo videos will help you get started:
- [Video: Introduction to Confidential Computing](https://mediacenter.ibm.com/media/Confidential+Computing+for+a+financial+transaction+using+Hyper+Protect+Virtual+Server+for+VPC/1_vv3j2oo6)
- [Blog: Advantages of deploying Vault in a Confidential Computing enclave](https://developer.ibm.com/articles/deploy-ibm-vault-linuxone/)
- [Tutorial: How to deploy Vault in a Confidential Computing enclave](https://developer.ibm.com/tutorials/awb-deploy-vault-securely-confidential-environment/)

