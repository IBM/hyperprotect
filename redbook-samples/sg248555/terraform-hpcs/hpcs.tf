terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.56.0"
    }
  }
}

# make sure to target the correct region and zone
provider "ibm" {
  region = var.region
  zone   = "${var.region}-${var.zone}"
  ibmcloud_api_key = var.ibmcloud_api_key
}

resource ibm_hpcs hpcs {
   location             = "${var.region}"
   name                 = "${var.hpcs_name}"
   plan                 = "standard"
   units                = 2
   signature_threshold  = 1
   revocation_threshold = 1
   admins {
     name  = "${var.hpcs_admin_1}"
     key   = abspath("${var.hpcs_admin_sigkey_1}")
     token = "${var.hpcs_admin_token_1}"
   }
}

# resource "ibm_iam_user_policy" "policy" {
#    ibm_id = "${var.hpcs_manager}"
#    roles  = ["Administrator"]

#    resources {
#      service = "${var.hpcs_name}"
#    }
# }

variable "ibmcloud_api_key" {
  description = <<-DESC
                  Enter your IBM Cloud API Key, you can get your IBM Cloud API key using:
                   https://cloud.ibm.com/iam#/apikeys
                DESC
  sensitive  = true
}

variable "region" {
  type        = string
  default     = "us-south"
  description = "Region to deploy to, e.g. eu-gb"

   validation {
    condition     = ( var.region == "eu-gb"  ||
                      var.region == "br-sao" ||
                      var.region == "ca-tor" ||
                      var.region == "jp-tok" ||
                      var.region == "us-south" ||
                      var.region == "us-east" )
    error_message = "Value of region must be one of eu-gb/br-sao/ca-tor/jp-tok/us-east."
  }
}

variable "zone" {
  type        = string
  default     = "1"
  description = "Zone to deploy to, e.g. 2."

  validation {
    condition     = ( var.zone == "1" ||
                      var.zone == "2" ||
                      var.zone == "3")
    error_message = "Value of zone must be one of 1/2/3."
  }
}

variable "hpcs_name" {
  type        = string
  default     = "redbook-sample"
  description = "Name of HPCS instance."
}

variable "hpcs_manager" {
  type        = string
  description = "Manager IBM cloud user id for the HPCS instance."
}

variable "hpcs_admin_1" {
  type        = string
  default     = "admin1"
  description = "HPCS admin."
}

variable "hpcs_admin_token_1" {
  type        = string
  description = "HPCS admin password."
  sensitive   = true
}

variable "hpcs_admin_sigkey_1" {
  type        = string
  default     = "./build/tke/1.sigkey"
  description = "HPCS admin."
}
