terraform {
  cloud {
    organization = "tibia-oce"
    workspaces {
      name = "tibia-oce"
    }
  }
}

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 4.64.0"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = ">= 0.34.0"
    }
  }
}

provider "hcp" {
  client_id     = var.hcp_client_id
  client_secret = var.hcp_client_secret
}

provider "oci" {
  private_key = data.hcp_vault_secrets_secret.oci_private_key.secret_value
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  region       = var.region
}
