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

# Configure the IBM Provider
# Target Frankfurt for now
provider "ibm" {
  region = "eu-de"
}

# This only provisions HPCS instance. User needs to manually do master key
# ceremony to initialize the HSM
resource "ibm_resource_instance" "hpcs" {
  name              = "TEST-HPCS-TERRAFORM-MINIMAL"
  service           = "hs-crypto"

  # Using the "standard" plan for now. The other available plan is
  # "hpcs-hourly-uko"
  # See https://cloud.ibm.com/catalog/services/hyper-protect-crypto-services
  plan              = "standard"
  location          = "eu-de"

  # Optional timeout
  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }

  # HPCS specific params
  parameters = {
    # Need 2 crypto units
    units: 2

    # No Failover crypto units
    failover_units: 0

    service_endpoints: "public-and-private"
 }
}
