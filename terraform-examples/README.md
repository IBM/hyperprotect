# Introduction

To start with, thanks for choosing Hyper Protect Services on IBM Cloud.
If you are sensitive about the security and want to be assured that cloud providers can't access your instance and data, then you are in the right place.

There are 4 products in Hyper Protect Services family. They are:

- [Hyper Protect Crypto Services](https://www.ibm.com/cloud/hyper-protect-crypto)
- [Hyper Protect Virtual Servers](https://www.ibm.com/cloud/hyper-protect-virtual-servers)
- [Hyper Protect DBaaS for PostgreSQL](https://cloud.ibm.com/docs/hyper-protect-dbaas-for-postgresql?topic=hyper-protect-dbaas-for-postgresql-gettingstarted&mhsrc=ibmsearch_a&mhq=hyper+protect+dbaas)
- [Hyper Protect DBaaS for MongoDB](https://cloud.ibm.com/docs/hyper-protect-dbaas-for-mongodb?topic=hyper-protect-dbaas-for-mongodb-gettingstarted&mhsrc=ibmsearch_a&mhq=hyper+protect+dbaas)

Each of these services can be provisioned via different methods. They are:
- IBM Cloud console UI
- Using REST APIs
- Using `ibmcloud` CLI
- Terraform

If you want to automate and use a standard framework, then Terraform is for you. Rest of this tutorial details how to provision each of these resources on IBM Cloud using Terraform.

### Estimated time
If you are new to Terraform, then the recommendation is that you get familiarity with using [Terraform](https://learn.hashicorp.com/terraform?utm_source=terraform_io) and come back to this. Once you know how to work with Terraform, going through this tutorial and setting everything up takes about 45 mins.

### Pre-requisites
It is required that the Terraform is [installed](https://learn.hashicorp.com/tutorials/terraform/install-cli) on the machine and the PATH variable is set appropriately. Execute `terraform --help` and make sure it works per expectation. All the examples in this tutorial were executed on Mac.

It is also required that you create an IAM API key using IBM cloud console.

Goto `Manager --> Access (IAM) --> API keys --> [Create an IBM Cloud API key]` and make sure to save the key content.

Also, make sure that `git ` is installed, so that you can just clone the samples and provision the resources. if you rather want to do it yourself, ignore the need to have git for this exercise, and refer the code [here](https://github.com/IBM/hyperprotect/tree/main/terraform-examples)

### Getting the hands dirty
- ***To begin with, let's provision the [Hyper Protect Virtual Servers - HPVS](https://cloud.ibm.com/catalog/services/hyper-protect-virtual-server).***

Follow these steps, and at the end of it all, you should see a fully provisioned HPVS ready to be used.
In this example, `Free` plan is used.

```
export IC_API_KEY = <API key that you created before>
git clone https://github.com/IBM/hyperprotect/terraform-examples/
cd terraform-examples/hpvs/
terraform init
terraform plan (Make sure everything is per expectation)
terraform apply ( Enter `yes` when it prompts for the user input. Alternatively, use `terraform apply --auto-approve` to bypass this)

Make sure to execute `terraform destroy` when you are done.
```
![](https://github.com/IBM/hyperprotect/blob/main/terraform-examples/hpvs/images/TEST-HPVS-TERRAFORM.png)
> This is how the provisioned instance looks like on IBM Cloud console.

And let's ssh into the provisioned instance.
```
% ssh -i private_key root@168.1.60.84
Last login: Thu Jul  7 12:58:02 2022 from 49.205.145.100
root@8901b5c858aa:~# ip add show eth0
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 56:72:de:9e:cc:4f brd ff:ff:ff:ff:ff:ff
    inet 172.19.23.155/29 brd 172.19.23.159 scope global eth0
       valid_lft forever preferred_lft forever
root@8901b5c858aa:~#
```
Note that, the above method provisions the HPVS using IBM stock image. If you are interested to bring in your own container image and do it through registration files, it can not be automated using Terraform at the moment.
Refer: https://developer.ibm.com/tutorials/running-a-minecraft-server-on-ibm-cloud-hyper-protect-virtual-servers/

- ***Now that we have created HPVS, let's go ahead create [Hyper Protect Crypto Services - HPCS](https://cloud.ibm.com/catalog/services/hyper-protect-crypto-services) now.***

Provisioning HPCS is an interesting task. Please note that there are no free plans for this service. In this exercise, `Standard` plan is what is chosen. There are 2 ways to provision it.

- **Method_1**
     - Instantiate HPCS, but do Master Key ceremony manually.
       - This is recommended for production
- **Method_2**
     - Instantiate HPCS, and also do the Master key ceremony automatically. 
       - This is **not** recommended for production. It can be only for dev/test activities as the master key will not be in the control of the user that is creating the HPCS instance. Terraform provider uses the recovery crypto units for doing the Master Key ceremony.

Let's look at **Method_1**. At the end of it, we shoud see a HPCS instance created waiting for you to do the Master key ceremony.
```
export IC_API_KEY = <API key that you created before>
git clone https://github.com/IBM/hyperprotect/terraform-examples/
cd terraform-examples/hpcs_minimal/
terraform init
terraform plan (Make sure everything is per expectation)
terraform apply ( Enter `yes` when it prompts for the user input. Alternatively, use `terraform apply --auto-approve` to bypass this)

Make sure to execute `terraform destroy` when you are done.
```
![](https://github.com/IBM/hyperprotect/blob/main/terraform-examples/hpcs_minimal/images/TEST-HPCS-TERRAFORM-MINIMAL.png)
> This is how the provisioned instance looks like on IBM Cloud console.

Now that the HPCS instance is created, please initialize the HSM via Master Key ceremony procedure before it can be used.
- https://cloud.ibm.com/docs/hs-crypto?topic=hs-crypto-initialize-hsm-management-utilities if you are using smart cards.
- https://cloud.ibm.com/docs/hs-crypto?topic=hs-crypto-initialize-hsm&locale=en-GB if you wish to do via command line tool `ibmcloud tke`.

Let's look at **Method_2**.  At the end of it, we should see a HPCS instance created with Master Key initialisation successfully completed, and ready to be used.
```
export IC_API_KEY = <API key that you created before>
git clone https://github.com/IBM/hyperprotect/terraform-examples/
cd terraform-examples/hpcs_full/

# Install `ibmcloud` CLI
# Refer: https://cloud.ibm.com/docs/cli?topic=cli-getting-started

# After installing `ibmcloud`, install TKE plugin and setup the TKE files directory
ibmcloud plugin install tke
mkdir tke_files
export CLOUDTKEFILES=</path/to/tke_files/>

# Create the TKE admin key that will be used for key ceremony. This key will be
# created in tke_files directory
ibmcloud tke sigkey-add (If you want to use the terraform sample code AS-IS, make sure you give the name as `Admin` and password as `passw0rd` when it prompts. If you want to use another name and password, make appropriate updates to the hpcs.tf)
terraform init
terraform plan (Make sure everything is per expectation)
terraform apply ( Enter `yes` when it prompts for the user input. Alternatively, use `terraform apply --auto-approve` to bypass this)

Make sure to execute `terraform destroy` when you are done.
```
![](https://github.com/IBM/hyperprotect/blob/main/terraform-examples/hpcs_full/images/TEST-HPCS-TERRAFORM.png)
> This is how the provisioned instance looks like on IBM Cloud console.

Now that the HPCS has been created, it is ready to be used.
Refer:
- https://cloud.ibm.com/apidocs/hs-crypto
- https://cloud.ibm.com/docs/hs-crypto?topic=hs-crypto-set-up-grep11-api

Alright, congratulations on setting up HPVS and HPCS. In the next section, we will see how to provision Hyper Protect DBaaS for MongoDB and Postgresql.

- ***Let's create an instance of [Hyper Protect DBaaS for MongoDB now](https://cloud.ibm.com/catalog/services/hyper-protect-dbaas-for-mongodb), and will get to Postgresql after this***. At the end of this, you should have a fully provisioned MongoDB instance that is ready to be used. 
```
export IC_API_KEY = <API key that you created before>
git clone https://github.com/IBM/hyperprotect/terraform-examples/
cd terraform-examples/hpdbass/mongodb/
terraform init
terraform plan (Make sure everything is per expectation)
terraform apply ( Enter `yes` when it prompts for the user input. Alternatively, use `terraform apply --auto-approve` to bypass this)

Make sure to execute `terraform destroy` when you are done.
```
![](https://github.com/IBM/hyperprotect/blob/main/terraform-examples/hpdbass/mongodb/images/HP-MONGODB-TERRAFORM.png)
> Here is how provisioned instance looks like on IBM Cloud console.

![](https://github.com/IBM/hyperprotect/blob/main/terraform-examples/hpdbass/mongodb/images/MONGO-COMPASS-CONNECTED.png)
> If you connect to it via MongoDB Compass, then it should look like this.  Make sure you download the certificate and reference that in MongoDB Compass tool while connecting.
> Note: Password used to connect is `Passw0rdPassw0rd` as that is what has been used while provisioning.

- ***Okay, last but not the least, [Hyper Protect DBaaS for Postgresql](https://cloud.ibm.com/catalog/services/hyper-protect-dbaas-for-postgresql) now***.
At the end of this, you should have a fully provisioned PostgresqlDB instance that is ready to be used. 
```
export IC_API_KEY = <API key that you created before>
git clone https://github.com/IBM/hyperprotect/terraform-examples/
cd terraform-examples/hpdbass/postgresql/
terraform init
terraform plan (Make sure everything is per expectation)
terraform apply ( Enter `yes` when it prompts for the user input. Alternatively, use `terraform apply --auto-approve` to bypass this)

Make sure to execute `terraform destroy` when you are done.
```
![](https://github.com/IBM/hyperprotect/blob/main/terraform-examples/hpdbass/postgresql/images/HP-POSTGRESQL-TERRAFORM.png)
> This is how the provisioned instance looks in IBM Cloud console

![](https://github.com/IBM/hyperprotect/blob/main/terraform-examples/hpdbass/postgresql/images/PGADMIN-CONNECTED.png)
> Here is how it looks when connected via PGAdmin tool. Make sure you download the certificate and reference that in PGAdmin tool while connecting.
> Note: Password used to connect is `Passw0rdPassw0rd` as that is what has been used while provisioning.

## Summary
In this tutorial, we have provisioned all the 4 Hyper Protect services, and are ready to begin the Confidential Computing journey.

## What next ?
It's now the time to put all the created instances to use. As a next step, consider doing these:
- Instantiate [IBM Log Analysis](https://cloud.ibm.com/catalog/services/logdna?callback=%2Fobserve%2Flogging%2Fcreate) and plug it with HPVS
    - Refer [this page](https://cloud.ibm.com/docs/hp-virtual-servers?topic=hp-virtual-servers-monitoring) to know how to configure the HPVS instance to communicate with the Log Analysis created above
- Explore [HPCS KMS features](https://cloud.ibm.com/apidocs/hs-crypto)
- Explore [HPCS EP11 features](https://cloud.ibm.com/docs/hs-crypto?topic=hs-crypto-grep11-api-ref)
- Try talking to HPCS instance through this [go code](https://github.com/IBM-Cloud/hpcs-grep11-go)
- Connect to MongoDB and PostgreSQL instances and push some data

At the end of all these, you would be in a good position to put the instances to real use.

## Related links
- Code and images available [here](https://github.com/IBM/hyperprotect/tree/main/terraform-examples)
    - This also has screenshots from MongoDB Compass and PGAdmin tools.
- Terraform provider [ibm_resource_instance](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/resource_instance) reference 
- Terraform provider [ibm_hpcs](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/hpcs) reference
- IBM Cloud [catalog](https://cloud.ibm.com/catalog)

## Have something to say about this tutorial ?
Feel free to add a comment or write to vishwanath at in dot ibm dot com
