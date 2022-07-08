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

resource "ibm_resource_instance" "mongodb_cluster" {
  name              = "TEST-HPMONGODB-TERRAFORM"
  service           = "hyperp-dbaas-mongodb"

  # Choosing free plan now. The only other plan is "mongodb-flexible"
  # See: https://cloud.ibm.com/catalog/services/hyper-protect-dbaas-for-mongodb
  plan              = "mongodb-free"
  location          = "eu-de"

  # Optional timeout
  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }

  # HPDBaaS specific params
  parameters = {
    name: "test-mongo-cluster",
    admin_name: "admin",
    password: "Passw0rdPassw0rd"
    confirm_password: "Passw0rdPassw0rd",
    db_version: "4.4"

    # Optionally, override the defaults.
    #cpu: "1",
    #memory: "2gib",
    #storage: "5gib"
    service-endpoints: "public",
 }
}
