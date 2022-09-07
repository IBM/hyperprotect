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

# Configure the IBM provider mapping to the location
provider "ibm" {
  region = "us-south"
}

# This code below creates a HPCS standard instance in `us-south`
# region and also does the master key ceremony automatically.
# At the end of this, the HPCS is available for business.
# Prior to this, we should have created the admin key
# and admin password using TKE plugin `ibmcloud tke sigkey-add`
resource ibm_hpcs hpcs {
  location             = "us-south"
  name                 = "TEST-HPCS-TERRAFORM"

  # Using the standard plan for now. The other available plan is
  # "hpcs-hourly-uko"
  # See https://cloud.ibm.com/catalog/services/hyper-protect-crypto-services
  plan                 = "standard"

  # Number of crypto units
  units                = 2

  # Number of Admin signature keys needed
  signature_threshold  = 1
  revocation_threshold = 1

  # Number of failover crypto units required
  failover_units       = 0
  service_endpoints    = "public-and-private"

  # This section below points to the admin signature key that is generated
  # by executing `ibmcloud tke sigkey-add`. Terraform uses this key when it
  # does the TKE master key ceremony to initialize the instance.
  admins {
    name  = "Admin"
    # 1.sigkey will be in tke_files directory. This code assumes that tke_files
    # is present in the same directory as this terraform file.
    # If not, put the complete path to the file
    key   = "./tke_files/1.sigkey"
    token = "passw0rd"
  }

  # Optional..
  timeouts {
    create = "55m"
    delete = "55m"
  }
}

output "hpcs_id" {
  value       = ibm_hpcs.hpcs.id
  description = "ID of the provisioned HPCS instance"
}
