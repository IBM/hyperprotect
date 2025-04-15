# Configuring Vault KMIP as Key Server for IBM Flash System

## Introduction
Storage Systems are data repositories that hold the key to data-at-rest security. Whether it is in the cloud or on an enterprise' on-premise infrastructure, storage systems have inbuilt data-protection. With multifold increase in cybersecurity incidents, regulations call for compliance with enhanced data protection standards. These standards require storage systems to obtain data-encryption-keys (DEKs) from a *Key Server*. A *Key Server*, in the context of a *Storage System*, is a [Key Management System (KMS)](https://en.wikipedia.org/wiki/Key_management#Key_management_system) that is accessible with [Key Management Interoeprability Protocol (KMIP)](https://en.wikipedia.org/wiki/Key_Management_Interoperability_Protocol). 

IBM announced the availability of [IBM Vault self-managed on IBM Z and LinuxONE](https://www.ibm.com/new/announcements/ibm-vault-self-managed-for-z-and-linuxone-and-ibm-nomad-self-managed-for-z-and-linuxone-generally-available). Vault provides a centralized approach to secrets management across every element of the application delivery lifecycle. It also provides a highly available and secure way of storing and exposing secrets to applications and users. Vault's capabilities can be enhanced by adding a KMIP-plugin, which enbales Vault to become a "Key Server" for Storage Systems.

This tutorial will provide step-by-step instructions on how to configure a Vault installation with a KMIP plugin and associating this Key Server with a storage system like [IBM Flash System](https://www.ibm.com/flashsystem). 

## Pre-reqs

## Step 1

## Step 2

## Conclusion
