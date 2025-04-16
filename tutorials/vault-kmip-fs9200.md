# Configuring Vault KMIP as Key Server for IBM Flash System

## Introduction
Storage Systems are data repositories that hold the key to *data-at-rest security*. Whether it is in the cloud or on an enterprise' on-premise infrastructure, storage systems have inbuilt data-protection. With multifold increase in cybersecurity incidents, regulations call for compliance with enhanced data protection standards. These standards require storage systems to obtain data-encryption-keys (DEKs) from a *Key Server*. A *Key Server*, in the context of a *Storage System*, is a [Key Management System (KMS)](https://en.wikipedia.org/wiki/Key_management#Key_management_system) that is accessible with [Key Management Interoeprability Protocol (KMIP)](https://en.wikipedia.org/wiki/Key_Management_Interoperability_Protocol). 

IBM announced the availability of [IBM Vault self-managed on IBM Z and LinuxONE](https://www.ibm.com/new/announcements/ibm-vault-self-managed-for-z-and-linuxone-and-ibm-nomad-self-managed-for-z-and-linuxone-generally-available). Vault provides a centralized approach to secrets management across every element of the application delivery lifecycle. It also provides a highly available and secure way of storing and exposing secrets to applications and users. Vault's capabilities can be enhanced by adding a KMIP-plugin, which enbales Vault to become a "Key Server" for Storage Systems.

This tutorial will provide step-by-step instructions on how to configure a Vault installation with a KMIP plugin and associating this Key Server with a storage system like [IBM Flash System](https://www.ibm.com/flashsystem). 

## Pre-reqs
- Access to s390x server | VM. If Vault needs to be configured in a Confidential Computing enclave, check [How to run IBM Vault in a Confidential Computing enclave?]()
- An IBM Vault Enterprise Vault License
- Admin access to an IBM Flash Subsystem
  

## Step 1
1. Logon to the s390x server
1. Prepare the environment
   ```
   export VAULT_HOME=/etc/vault.d
   export VAULT_RAFT=/opt/vault/data
   mkdir -p $VAULT_HOME
   mkdir -p $VAULT_RAFT
   cd $VAULT_HOME
   ```
1. Download the latest version of Vault-s390x from [releases.hashicorp.com](https://releases.hashicorp.com/vault/1.19.1+ent/) and check if Vault looks good:
   ```
   wget https://releases.hashicorp.com/vault/1.18.4+ent/vault_1.18.4+ent_linux_s390x.zip
   unzip vault_1.18.4+ent_linux_s390x.zip
   ./vault version
   ```
1. Create the Vault License file by copying into a file `$VAULT_HOME/vault-ent-license.hclic`
1. Apply the vault license
   ```
   export VAULT_LICENSE=$VAULT_HOME/vault-ent-license.hclic
   ```
1. Copy [vault-sample-config.hcl](configuration-files/vault-sample-config.hcl) to `$VAULT_HOME/vault-config.hcl`
1. Start the Vault server:
   ```
   ./vault server -config=$VAULT_HOME/vault-config.hcl
   ```
   Expect a sample output like this [vault-startup-sample-output](sample-files/vault-startup-sample-output)

## Step 2

## Conclusion
