provider "oci" {
  tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaag3xw32hdfohhaxtbrgqn7bukopofevsijbhbh6y6fgo5u3vnirpq"
  user_ocid        = "ocid1.user.oc1..aaaaaaaa3bnkhue5jyet7ny2wdtj4y2ll4mcb57ijqv2eylpqnxbwkuovhea"
  private_key_path = "~/.oci/oci_api_key.pem"
  fingerprint      = "cc:41:4c:e9:ab:62:cf:0a:d0:c9:59:41:38:fb:f4:75"
  region           = "eu-paris-1"
}

terraform {
  required_providers {
    gandi = {
      version = "~> 2.0"
      source  = "go-gandi/gandi"
    }
    oci = {
      version = "~> 6.0"
      source  = "oracle/oci"
    }

    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "gandi" {
  key = var.gandi_api_key
}
