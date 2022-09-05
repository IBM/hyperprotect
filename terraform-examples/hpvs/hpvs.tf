terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.39.0"
    }
    local = {
      source = "hashicorp/local"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}

# Configure the IBM Provider. This is targeting Sydney, Australia region
provider "ibm" {
  region = "ap-aud"
}

# Create HPVS instance
resource "ibm_resource_instance" "hpvs" {
  name              = "TEST-HPVS-TERRAFORM"
  service           = "hpvs"

  # Choosing "free/lite-s" for this test. The other valid plans are:
  # "entry", "small", "medium"
  # See https://cloud.ibm.com/catalog/services/hyper-protect-virtual-server
  plan              = "lite-s"

  # Chose where you want the instance provisioned. This is targeting Sydney
  location          = "syd01"

  # Optional timeout
  timeouts {
    create = "30m"
    update = "15m"
    delete = "30m"
  }

  # HPVS specific params.
  # After the instance is provisioned, ssh access works only with the private
  # key that is associated with the public key given here.
  # trimspace needed because the public key sometimes appended with \n
  parameters = {
    sshPublicKey: trimspace(tls_private_key.ssh_key.public_key_openssh)
  }
}
