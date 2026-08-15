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
