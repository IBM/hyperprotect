terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.4"
    }

    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.56.0"
    }

    hpcr = {
      source  = "ibm-hyper-protect/hpcr"
      version = ">= 0.2.7"
    }
  }
}

# make sure to target the correct region and zone
provider "ibm" {
  region = var.region
  zone   = "${var.region}-${var.zone}"
  ibmcloud_api_key = var.ibmcloud_api_key
}

# locate the latest hyper protect image
data "ibm_is_images" "hyper_protect_images" {
  visibility = "public"
  status     = "available"
}

locals {
  # some reusable tags that identify the resources created by his sample
  tags = ["tf", "hpcr", var.prefix]

  # filter the available images down to the hyper protect one
  hyper_protect_image = element([for image in data.ibm_is_images.hyper_protect_images.images : image if image.os == "hyper-protect-1-0-s390x" && image.architecture == "s390x"], 0)
}

# the VPC
resource "ibm_is_vpc" "hpcr_vpc" {
  name = format("%s-vpc", var.prefix)
  tags = local.tags
}

# the security group
resource "ibm_is_security_group" "hpcr_security_group" {
  name = format("%s-security-group", var.prefix)
  vpc  = ibm_is_vpc.hpcr_vpc.id
  tags = local.tags
}

# rule that allows the VSI to make outbound connections, this is required
# to connect to the logDNA instance as well as to docker to pull the image
resource "ibm_is_security_group_rule" "hpcr_outbound" {
  group     = ibm_is_security_group.hpcr_security_group.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

# rule that allows inbound traffic to the nginx server
resource "ibm_is_security_group_rule" "hpcr_inbound_container_http" {
  group     = ibm_is_security_group.hpcr_security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 80
    port_max = 80
  }
}

# rule that allows inbound traffic to the nginx server
resource "ibm_is_security_group_rule" "hpcr_inbound_container_https" {
  group     = ibm_is_security_group.hpcr_security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 443
    port_max = 443
  }
}

# the subnet
resource "ibm_is_subnet" "hpcr_subnet" {
  name                     = format("%s-subnet", var.prefix)
  vpc                      = ibm_is_vpc.hpcr_vpc.id
  total_ipv4_address_count = 64
  zone                     = "${var.region}-${var.zone}"
  tags                     = local.tags
}

# create a random key pair, because for formal reasons we need to pass an SSH key into the VSI. It will not be used, that's why
# it can be random
resource "tls_private_key" "hpcr_rsa_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# we only need this because VPC expects this
resource "ibm_is_ssh_key" "hpcr_sshkey" {
  name       = format("%s-key", var.prefix)
  public_key = tls_private_key.hpcr_rsa_key.public_key_openssh
  tags       = local.tags
}

# archive of the folder containing docker-compose file. This folder could create
# additional resources such as files to be mounted into containers, environment
# files etc. This is why all of these files get bundled in a tgz file (base64
# encoded)
resource "hpcr_tgz" "contract" {
  folder = "sample"
}

locals {
  # contract in clear text
  contract = <<-EOF
    workload:
      type: workload
      play:
        archive: ${hpcr_tgz.contract.rendered}
      volumes:
        data1:
          filesystem: ext4
          mount: /mnt/data1
          seed: "secret workload phrase"
    env:
      type: env
      logging:
        logDNA:
          ingestionKey: "${var.logdna_ingestion_key}"
          hostname: "${var.logdna_ingestion_hostname}"
      volumes:
        data1:
          seed: "secret env phrase"
          kms:
            - crn: "${var.hpcs_crn}"
              apiKey: "${var.hpcs_api_key}"
              type: "public"
    attestationPublicKey: |-
      ${replace(trimspace("${tls_private_key.attestation_enc_rsa_key.public_key_pem}"), "\n", "\n  ")}
  EOF
}

# create a key pair for the purpose of encrypting the attestation record
resource "tls_private_key" "attestation_enc_rsa_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# In this step we encrypt the fields of the contract and sign the env and
# workload field. The certificate to execute the encryption it built into the
# provider and matches the latest HPCR image. If required it can be overridden.
# We use a temporary, random keypair to execute the signature. This could also
# be overridden.
resource "hpcr_contract_encrypted" "contract" {
  contract = local.contract
  cert     = file(var.enc_file_name)
}

resource "ibm_is_volume" "hpcr_data" {
  name     = format("%s-data1", var.prefix)
  profile  = "general-purpose"
  zone     = "${var.region}-${var.zone}"
  capacity = 10
  tags     = local.tags
}

# construct the VSI
resource "ibm_is_instance" "hpcr_vsi" {
  name    = format("%s-vsi", var.prefix)
  image   = local.hyper_protect_image.id
  profile = var.profile
  keys    = [ibm_is_ssh_key.hpcr_sshkey.id]
  vpc     = ibm_is_vpc.hpcr_vpc.id
  tags    = local.tags
  zone    = "${var.region}-${var.zone}"
  availability_policy_host_failure = "stop"

  boot_volume {
    tags = local.tags
  }
  volumes = [ibm_is_volume.hpcr_data.id]

  # the user data field carries the encrypted contract, so all information visible at the hypervisor layer is encrypted
  user_data = hpcr_contract_encrypted.contract.rendered

  primary_network_interface {
    name            = "eth0"
    subnet          = ibm_is_subnet.hpcr_subnet.id
    security_groups = [ibm_is_security_group.hpcr_security_group.id]
  }
}

# attach a floating IP since we would like to access the embedded server via the internet
resource "ibm_is_floating_ip" "hpcr_floating_ip" {
  name   = format("%s-floating-ip", var.prefix)
  target = ibm_is_instance.hpcr_vsi.primary_network_interface[0].id
  tags   = local.tags
}

# log the floating IP for convenience
output "ip" {
  value = resource.ibm_is_floating_ip.hpcr_floating_ip.address
  description = "The public IP address of the VSI"
}

resource "local_file" "ip_file" {
  content = ibm_is_floating_ip.hpcr_floating_ip.address
  file_permission = "0664"
  filename = "ip"
}

# output the contract as a plain text (debugging purpose)
resource "local_file" "user_data_plain" {
  content  = local.contract
  file_permission = "0664"
  filename = "user-data-plain"
}

# output the contract (encrypted)
resource "local_file" "user_data" {
  content  = hpcr_contract_encrypted.contract.rendered
  file_permission = "0664"
  filename = "user-data"
}

resource "local_file" "attestation_enc" {
  content = tls_private_key.attestation_enc_rsa_key.private_key_pem
  file_permission = "0600"
  filename = "attestation_enc"
}

resource "local_file" "attestation_enc_pub" {
  content = tls_private_key.attestation_enc_rsa_key.public_key_pem
  file_permission = "0664"
  filename = "attestation_enc.pub"
}
