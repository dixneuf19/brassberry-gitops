provider "oci" {
  tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaag3xw32hdfohhaxtbrgqn7bukopofevsijbhbh6y6fgo5u3vnirpq"
  user_ocid        = "ocid1.user.oc1..aaaaaaaa3bnkhue5jyet7ny2wdtj4y2ll4mcb57ijqv2eylpqnxbwkuovhea"
  private_key_path = "~/.oci/oci_api_key.pem"
  fingerprint      = "b0:56:46:49:33:1d:e5:b5:7d:64:26:c8:e7:ef:90:fc"
  region           = "eu-paris-1"
}

terraform {
  required_providers {
    gandi = {
      version = "~> 2.0"
      source  = "go-gandi/gandi"
    }
    oci = {
      version = "~> 8.0"
      source  = "oracle/oci"
    }

    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "gandi" {
  personal_access_token = var.gandi_pat
}
