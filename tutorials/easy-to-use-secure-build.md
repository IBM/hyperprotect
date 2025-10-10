# Easy to follow Secure Build documentation
This doc is based on [Building your applications with Hyper Protect Secure Build](https://www.ibm.com/docs/en/hpvs/2.2.x?topic=building-your-applications-hyper-protect-secure-build). It is intended to provide a concise view of the entire Secure Build download / configuration process. Information contained in this document will be integrated into the official documentation in the future, until then it should be considered as a `work in progress`.

## High level overview
With IBM Hyper Protect Secure Build, you can build a trusted container image within a secure enclave that is provided by IBM Hyper Protect Virtual Servers. The enclave is highly isolated, where developers can access the container only by using a specific API and the administrator cannot access the contents of the container. Therefore, the image that is built can be highly trusted.

## Pre-requisites
- access to an s390x machine - IBM Z / LinuxONE LPAR / VM
- access to [IBM Passport Advantage](https://www-01.ibm.com/software/passportadvantage/pao_customer.html)
- API-Key to a Container Registry. This tutorial will use [IBM Container Registry (ICR)](https://www.ibm.com/products/container-registry)

## Steps

### Step 1 - Register the HPSB image
- Logon to the s390x machine
- Download the HPSB image as documented here: https://www.ibm.com/docs/en/hpvs/2.2.x?topic=build-downloading-hyper-protect-secure-image

```
mkdir -p ~/secure-build-cli
export ICR_KEY=<api-key>
export SB_HOME=~/secure-build-cli
export ICR_REGION=us.icr.io
export ICR_NAMESPACE=hps-secure-build
docker load < $SB_HOME/images/hyper-protect-secure-build.tar.gz
docker tag de.icr.io/zaas-hpvsop-prod/secure-docker-build:1.3.0.19 $ICR_REGION/$ICR_NAMESPACE/secure-docker-build:1.3.0.19
docker push $ICR_REGION/$ICR_NAMESPACE/secure-docker-build:1.3.0.19
```
The example above will push the `secure-docker-build image` to the IBM Container Registry and available at `us.icr.io/hps-secure-build/secure-docker-build:1.3.0.19`

### Step 2 - Create the server configuration
```
cd $SB_HOME
vim sbs-config.json
```
- copy-paste the following content into `sbs-config.json`:
```
{
  "HOSTNAME": "sbs.example.com",
  "CICD_PORT": "443",
  "IMAGE_TAG": "1.3.0.19",
  "CONTAINER_NAME": "SBContainer",
  "RUNTIME_TYPE": "on-prem",
  "GITHUB_KEY_FILE": "~/.ssh/id_rsa",
  "GITHUB_URL": "git@github.com:<git_user>/<git_repo>.git",
  "GITHUB_BRANCH": "main",
  "DOCKER_REPO": "$ICR_REGION/$ICR_NAMESPACE/<docker-image-name>",
  "DOCKER_USER": "iamapikey",
  "DOCKER_PASSWORD": "$ICR_KEY",
  "IMAGE_TAG_PREFIX": "<docker_image_tag>",
  "DOCKER_CONTENT_TRUST_BASE": "False",
  "DOCKER_CONTENT_TRUST_BASE_SERVER": "",
  "DOCKER_RO_USER": "iamapikey",
  "DOCKER_RO_PASSWORD": "$ICR_KEY",
  "DOCKER_BASE_USER": "",
  "DOCKER_BASE_PASSWORD": "",
  "ICR_BASE_REPO": "",
  "ICR_BASE_REPO_PUBLIC_KEY": "",
  "ENV_WHITELIST":  ["<KEY1>", "<KEY2>"],
  "ARG": {
    "<BUILD_ARG1>": "<VALUE1>",
    "<BUILD_ARG2>": "<VALUE2>"
  }
}
```
- Update the following as required:
  - `HOSTNAME` - The hostname of the HPSB server which will be used while generating certificates and communicating with the secure build server.
  - `RUNTIME_TYPE` - Set to on-prem to leverage IBM Hyper Protect Virtual Servers.
  - `CICD_PORT` - The port on which a build service is running (default: 443).
  - `IMAGE_TAG` - The container image tag to be deployed as the HPSB server. Use 1.3.0.19 unless otherwise noted.
  - `CONTAINER_NAME` - The name of the HPSB instance that you want to create. The name is used as a part of a certificate file name. You can choose any valid string as a file name.
  - `GITHUB_KEY_FILE` - The private key path to access your GitHub repo. This **must not** have a passphrase.
  - `GITHUB_URL` - The GitHub repo of the source code repo.
  - `GITHUB_BRANCH` - The GitHub branch name of the source code repo.
  - `DOCKER_REPO` - The DockerHub repository to store the built image.
  - `DOCKER_USER` - The docker user name with the write access to the repository.
  - `DOCKER_PASSWORD` - The docker password with the write access to the repository.
  - `IMAGE_TAG_PREFIX` - The prefix of the image tag for the image to be built. The full image tag will be - `IMAGE_TAG_PREFIX` + '-' + the leading seven digits from the GitHub repository hash.
  - `DOCKER_CONTENT_TRUST_BASE` - If your base image that mentioned in the Dockerfile is signed, then set it true.
  - `DOCKER_CONTENT_TRUST_BASE_SERVER` - If your base image mentioned in the Dockerfile is signed, then you can specify the notary URL. The default value is https://notary.docker.io.
  - `DOCKER_BASE_USER` - The docker user name of repository that has the the base image.
  - `DOCKER_BASE_PASSWORD` - The docker password of repository that has base image.
  - `DOCKER_RO_USER` - You can use the same value as the DOCKER_USER. It is recommended that you specify a user who has the read access only to your Docker repository.
  - `DOCKER_RO_PASSWORD` - You can use the same value as the DOCKER_PASSWORD. It is recommended that you specify a user who has the read access only to your Docker repository.
  - `ENV_WHITELIST` - All environment variable names need to be listed. The Hyper Protect Virtual Servers only accept the environment variables in this list because of the security reasons.
  - `ARG` - You have to pass all build argument parameters in this parameter during the Docker build.
  - `ICR_BASE_REPO` - The base Image used in the dockerfile if it is present in IBM Cloud Registry (ICR).
  - `ICR_BASE_REPO_PUBLIC_KEY` - The public key with which the base image specified in the ICR_BASE_REPO is signed.

`ICR_BASE` or `DOCKER_BASE` will be used depending on where the **base** image used in the Dockerfile will be.

This configuration assumes the `Dockerfile` to be built in at the top level of the repo being referenced.

Additional optional build parameters can be used to specify a different directory:
- `DOCKERFILE_PATH` - defines the path name of the Dockerfile to be used during a build
- `DOCKER_BUILD_PATH` - defines the build directory

Both are relative to the top of the repo directory.

### Step 3 - Create the required certificates
```
cd $SB_HOME
./build.py create-client-cert --env $SB_HOME/sbs-config.json
./build.py create-server-cert --env $SB_HOME/sbs-config.json
./build.py instance-env --env $SB_HOME/sbs-config.json
```
- Take note of the values of `CLIENT_CRT`, `CLIENT_CA`, `SERVER_CRT`, `SERVER_KEY`. These will be used in the next step.

### Step 4 - Prepare the ENV section of the HPVS contract
```
mkdir $SB_HOME/contract
cd $SB_HOME/contract
vim env.yaml
```
- Copy/Paste the following content to the file:
```
env: |
  type: env
  logging:
    logRouter:
      hostname: <logging-hostname>
      iamApiKey: <logging-key>
  auths:
    us.icr.io:
      password: $ICR_KEY
      username: iamapikey
  volumes:
    hpsb:
      seed: "testing"
  env:
    registry: "us.icr.io/hps-secure-build/secure-docker-build"
    CLIENT_CRT:
    CLIENT_CA:
    SERVER_CRT:
    SERVER_KEY:
```
- Populate the 4 environment variables with values from the previous step

### Step 5 - Prepare the WORKLOAD section of the HPVS contract
```
vim workload.yaml
```
- Copy/Paste the following into `workload.yaml`:
```
workload: hyper-protect-basic.Dkz/tPLen9ZF8/sLRUH19RdKC6Z9aT8XZh1xbClnbLOyZzu/PQcqO9poMoFovCewhgZqAcsFNeqUqjbLpqZBYgktQGT4gjvYXimS1eUgmhgaACIUehuZL3wxkqkFKUXtsaQTKDbQxsjc/E2zTrVQ09+RCX+hJf+AuWZkbVkt4h3mFtDPEORA/LuWUEnx2rMTJFpiAcsoOtO2zsWrEpnxN36zWyzy8rsuoUFHQDm6R/vAvQ56ELf+n0MrAtwORX8OffAtqO75u/3xjf261pGctv0P638sqYC73Hr07dX+LT12bOOwql6iG+rPxhU5qcwzsmdkO48ysquQgi6Azwat5ohDALKZ8nMe6wDPnghltLMl3q8WndtEdKHV6XbqoouaM6PpfV8jVKt8ym1+39mrqEvbx9EK2r2uK5IDP6HuqNooDivJebxyo7sgHbHksW0iqHOJJpI3caMlCJEwZFPzF62CvV05wpQnwUKogEe55dDMXFoM4y1v/2UIa8YaZdcdFcKb4C5YfvHhF6nxg4jcz7iKw/pVeF0mZMkP8FQsM4woms6fu+O7UdemPlg9jO05HDArAJBaBPTt6qFZpx+wojYEb15TsufroPLeAYJk8gm278OrszZrZijFhihaNXXwpYQUZOdugnLf5PEWb5zx9a3YNZhFkALvYTuSFf/DAhc=.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
```

### Step 6. Encrypt the ENV section (optional)
```
export ENV=$SB_HOME/env.yaml
export CONTRACT_KEY=/root/hpvs/config/certs/ibm-hyper-protect-container-runtime-25.4.0-encrypt.crt
export PASSWORD="$(openssl rand 32 | base64 -w0)"
export ENCRYPTED_PASSWORD="$(echo -n "$PASSWORD" | base64 -d | openssl rsautl -encrypt -inkey $CONTRACT_KEY  -certin | base64 -w0)"
export ENCRYPTED_ENV="$(echo -n "$PASSWORD" | base64 -d | openssl enc -aes-256-cbc -pbkdf2 -pass stdin -in "$ENV" | base64 -w0)"
echo "env: hyper-protect-basic.${ENCRYPTED_PASSWORD}.${ENCRYPTED_ENV}" > user-data
```

### Step 7. Assemble the contract
- append workload to user-data
  ```
  cat workload.yaml >> user-data
  ```
- append env to user-data
  ```
  cat env.yaml >> user-data
  ```
- create the surrounding Hyper Protect config:
  ```
  cd $SB_HOME/contract
  echo "local-hostname: myhost" > meta-data
  vim vendor-data
  ```
  copy/paste the following into `vendor-data`
  ```
  #cloud-config
  users:
  - default
  ```

### Step 8. Build the HPSB Server image
```
genisoimage -input-charset utf-8 -output cidata.iso -volid cidata -joliet -rock meta-data user-data vendor-data
mv cidata.iso /var/lib/libvirt/images/hpcr/
vim sbs.xml
```
Copy/Paste the following into `sbs.xml`:
```
<domain type='kvm'>
  <name>sbs</name>
  <uuid>d2773016-3638-11f0-b74a-ca7bb8760dba</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://redhat.com/rhel/9.4"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit='KiB'>9194304</memory>
  <vcpu placement='static'>2</vcpu>
  <os>
    <type arch='s390x' machine='s390-ccw-virtio-rhel9.4.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <cpu mode='host-model' check='partial'/>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' iommu='on'/>
      <source file='/var/lib/libvirt/images/hpcr/ibm-hyper-protect-container-runtime-25.4.0.qcow2' index='2'/>
      <backingStore/>
      <target dev='vda' bus='virtio'/>
      <alias name='virtio-disk0'/>
      <address type='ccw' cssid='0xfe' ssid='0x0' devno='0x0000'/>
    </disk>
    <disk type='file' device='disk'>
      <driver name='qemu' type='raw' cache='none' io='native' iommu='on'/>
      <source file='/var/lib/libvirt/images/hpcr/cidata.iso'/>
      <target dev='vdb' bus='virtio'/>
      <readonly/>
      <address type='ccw' cssid='0xfe' ssid='0x0' devno='0x0002'/>
    </disk>
    <disk type='file' device='disk'>
      <driver name='qemu' type='raw' cache='none' iommu='on'/>
      <source file='/var/lib/libvirt/images/storage/datavolume'/> // Location where volume is created
      <target dev='vdd' bus='virtio'/> // This volume disk is located in the guest VM
      <serial>test1</serial>
      <address type="ccw" cssid="0xfe" ssid="0x0" devno="0xc28c"/>
    </disk>
    <controller type='pci' index='0' model='pci-root'/>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
      <driver name='vhost' iommu='on'/>
      <address type='ccw' cssid='0xfe' ssid='0x0' devno='0x0001'/>
    </interface>
    <console type='pty'>
      <target type='sclp' port='0'/>
    </console>
    <memballoon model='none'/>
    <panic model='s390'/>
  </devices>
</domain>
```


### Step 9. Start the HPSB Server
```
virsh define sbs.xml
virsh start sbs --console
```

- Retrieve IP of the instance once started and add it to hosts file
```
virsh net-dhcp-leases default
export SB_IP=<sbs-host-IP-address> 
echo $SB_IP sbs.example.com >> /etc/hosts
```

### Step 10 - Build the referenced image
- Check the Secure Build server status:
  ```
  ./build.py status --env $SB_HOME/sbs-config.json
  ```
  Expected response:
  ```
    INFO:__main__:status: response={
    "status": ""
    }
  ```
- Initialize & Build the image:
  ```
  ./build.py init --env $SB_HOME/sbs-config.json
  ./build.py build --env $SB_HOME/sbs-config.json
  ```
- Check build status:
  ```
  ./build.py status --env $SB_HOME/sbs-config.json
  ```
- View the full build log:
  ```
  ./build.py log --log build --env $SB_HOME/sbs-config.json
  ```
- Once run successfully you can visit your container registry to see if the new securely built image has been pushed.
  ```
  ./build.py get-digest --env sbs-config.json
  ```
