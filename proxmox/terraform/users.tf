# =============================================
# Users, Roles, and ACLs
#
# The terraform@pam user and token are created by the Ansible bootstrap
# playbook. The import blocks below bring them into Terraform state
# automatically on the first `terraform apply`.
# =============================================

import {
  to = proxmox_virtual_environment_user.terraform
  id = "terraform@pam"
}

import {
  to = proxmox_virtual_environment_user_token.terraform
  id = "terraform@pam!terraform-token"
}

import {
  to = proxmox_virtual_environment_acl.terraform_admin
  id = "/?terraform@pam?Administrator"
}

resource "proxmox_virtual_environment_user" "terraform" {
  user_id = "terraform@pam"
  comment = "Terraform automation"
  enabled = true

  lifecycle {
    # ACL is returned inline by the API but managed via the standalone
    # proxmox_virtual_environment_acl resource. Ignore it here to prevent
    # Terraform from revoking permissions during apply.
    ignore_changes = [acl]
  }
}

resource "proxmox_virtual_environment_user_token" "terraform" {
  user_id              = proxmox_virtual_environment_user.terraform.user_id
  token_name           = "terraform-token"
  privileges_separation = false
  comment              = "Terraform API token"
}

resource "proxmox_virtual_environment_acl" "terraform_admin" {
  path    = "/"
  user_id = proxmox_virtual_environment_user.terraform.user_id
  role_id = "Administrator"
}
