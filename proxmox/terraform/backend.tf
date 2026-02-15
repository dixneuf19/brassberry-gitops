terraform {
  backend "s3" {
    bucket = "dixneuf19-tfstates"
    key    = "proxmox/terraform.tfstate"
    region = "fr-par"

    endpoints = {
      s3 = "https://s3.fr-par.scw.cloud"
    }

    # Required for S3-compatible backends (non-AWS)
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
