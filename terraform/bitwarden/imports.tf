# Adoption of the GitHub App secrets created by hand (terraform/github/README.md).
# Import blocks are no-ops once the secrets are in the state.

import {
  to = bitwarden-secrets_secret.burrito_github_app_id
  id = "493c6502-092e-4bfa-887b-b4a700b75e4f"
}

import {
  to = bitwarden-secrets_secret.burrito_github_app_installation_id
  id = "e0c999af-972c-460a-8457-b4a700b9579e"
}

import {
  to = bitwarden-secrets_secret.burrito_github_app_private_key
  id = "cb013741-5f0d-4fbe-a744-b4a700b827a6"
}

import {
  to = bitwarden-secrets_secret.burrito_github_webhook_secret
  id = "db403ea6-90b3-4680-835f-b4a700b6a5c4"
}

import {
  to = bitwarden-secrets_secret.github_user
  id = "4a5f4a0d-5969-4e87-8f81-b4a700e613dc"
}

import {
  to = bitwarden-secrets_secret.oci_compartment_id
  id = "a57bab3f-ada8-4769-8157-b4a700e6140d"
}

import {
  to = bitwarden-secrets_secret.oci_node_ips
  id = "da31b3ef-ce27-4a71-85ac-b4a700e6143e"
}

import {
  to = bitwarden-secrets_secret.tailscale_auth_key
  id = "fb8ee74d-3c26-4a3e-b35e-b4a700e61490"
}

import {
  to = bitwarden-secrets_secret.oci_api_private_key
  id = "dcdcc394-4d04-4a40-9ac6-b4a700e634b9"
}
