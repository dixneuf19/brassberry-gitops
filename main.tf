variable "github_user" {
  type = string
}

variable "oci_compartment_id" {
  type = string
}

variable "tailscale_auth_key" {
  type      = string
  sensitive = true
}

variable "gandi_api_key" {
  type      = string
  sensitive = true
}

variable "node_ips" {
  type = list(string)
}
