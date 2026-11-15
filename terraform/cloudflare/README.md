# terraform/cloudflare

Cloudflare resources. For now: Email Routing for `mangococo.fr`, where some
addresses forward to several mailboxes. Routing rules only take one
destination, so those addresses point to an Email Worker
(`worker/email-forward.js`) that calls `message.forward()` once per
destination.

Rules not listed in the forwarding map (the catch-all, single-destination
rules made in the dashboard) are not managed here.

## Forwarding map

The repo is public, so destination mailboxes stay out of git. The map lives
in the Bitwarden secret `mangococo-email-forwards`, as JSON:

```json
{
  "contact@mangococo.fr": ["someone@example.org", "other@example.net"]
}
```

It reaches Terraform as `TF_VAR_mangococo_email_forwards` (repo `.envrc`
locally, `burrito-runner-cloudflare` ExternalSecret in the cluster). The
Worker gets it through a `secret_text` binding, and destination resources are
keyed by a hash of the address, so plans only show the source addresses.

To change it, use `scripts/forwards.py` (wraps `bws`):

```bash
./scripts/forwards.py list
./scripts/forwards.py set contact@mangococo.fr a@example.org b@example.net
./scripts/forwards.py rm contact@mangococo.fr
```

Then `direnv reload` and `terraform apply` here, or let Burrito pick it up
(ExternalSecret refresh plus drift detection, within about 1h).

A new destination gets a verification email from Cloudflare. Forwarding to it
fails until its owner clicks the link.

## One-time setup

1. Create an API token in the Cloudflare dashboard (My Profile, API Tokens),
   scoped to the account and the `mangococo.fr` zone:
   - Account: Workers Scripts Edit, Email Routing Addresses Edit
   - Zone: Zone Read, Email Routing Rules Edit
2. Apply `terraform/bitwarden` to create `cloudflare-api-token` and
   `mangococo-email-forwards` (placeholder values)
3. Write the real values: `bws secret list` to get the IDs, then
   `bws secret edit <id> --value <token-or-json>`
4. `direnv reload`, then `terraform init && terraform plan` here
5. If a dashboard rule already matches one of the source addresses, delete it
   or adopt it with an `import` block before applying (two literal rules on
   the same address conflict)
