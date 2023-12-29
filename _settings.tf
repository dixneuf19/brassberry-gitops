provider "oci" {
  tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaag3xw32hdfohhaxtbrgqn7bukopofevsijbhbh6y6fgo5u3vnirpq"
  user_ocid        = "ocid1.user.oc1..aaaaaaaa3bnkhue5jyet7ny2wdtj4y2ll4mcb57ijqv2eylpqnxbwkuovhea"
  private_key_path = "~/.ssh/oracle_cloud_tf.pem"
  fingerprint      = "12:e5:aa:ed:4e:9f:b7:bf:65:a8:7b:33:9c:06:82:fb"
  region           = "eu-paris-1"
}

terraform {
  required_providers {
    gandi = {
      version = "~> 2.0"
      source  = "go-gandi/gandi"
    }
    oci = {
      version = "~> 5.0"
      source  = "oracle/oci"
    }
  }
}

provider "gandi" {
  key = var.gandi_api_key
}
