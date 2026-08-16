variable "github_user" {
  type = string
}

variable "oci_compartment_id" {
  type = string
}

variable "gandi_pat" {
  type      = string
  sensitive = true
}

variable "node_ips" {
  type = list(string)
}

variable "oci_private_key_path" {
  type    = string
  default = "~/.oci/oci_api_key.pem"
}
