## Why

`cimetiere@mangococo.fr` is one anonymous list for the whole band, and only Julen (or Claude) can change its members, by editing a Bitwarden secret and applying Terraform. The band wants smaller anonymous lists for subsets of people, created and filled by the members themselves, by email, without asking Julen.

## What Changes

- **Concessions:** a concession is a named, anonymous, members-only list inside the cimetière, reached at `cimetiere+<concession>@mangococo.fr`. A post is re-sent to the concession's members from that address, so replies come back to the concession.
- **The fossoyeur:** `fossoyeur@mangococo.fr` takes commands written in the mail body, in cemetery words: `acheter` a concession, `enterrer` people in it, `exhumer` yourself, read its `registre`, see your `plan`. Anything it does not understand gets the help text back.
- **Members move to Workers KV:** the main cimetière and every concession keep their members in one KV namespace, written by the Worker. The Bitwarden secret `ragots-members`, `TF_VAR_ragots_members` and `scripts/ragots.py` go away; a new `scripts/cimetiere.py` gives Julen admin access to KV.
- **Registration:** `enterrer` registers new addresses as Cloudflare destination addresses through the API, which sends them the verification email the free plan requires. The Worker gets its own API token, created by Terraform.
- **Notifications:** Julen gets a mail for every concession bought and every person buried.
- **Subaddressing** is turned on for the zone, so `cimetiere+<concession>@` matches the existing `cimetiere@` rule. `contact@`'s Worker learns to ignore the `+` part.
- `contact@mangococo.fr` keeps its forwarding map in Bitwarden, unchanged.

## Capabilities

### New Capabilities

- `cimetiere`: the main list and its concessions, who can post, how copies are anonymised and addressed, and where members are stored.
- `fossoyeur`: the command mailbox, its vocabulary, permissions, replies and notifications, and the registration of new addresses.

### Modified Capabilities

None. `openspec/specs/` holds nothing about mail yet.

## Impact

- **Terraform (`terraform/cloudflare`, Burrito auto-apply):** a KV namespace, an account-owned API token, `support_subaddress` on the zone, new bindings on `cloudflare_workers_script.ragots`, `fossoyeur@` added to the `ragots` rules. `var.ragots_members` is removed.
- **Cloudflare token used by Terraform:** needs two more permissions, "Account API Tokens Write" (to create the Worker's token) and "Workers KV Storage Write" (for the one-off migration and `scripts/cimetiere.py`). Julen adds them in the dashboard.
- **Bitwarden:** `ragots-members` is deleted after the migration, along with its `.envrc` export and ExternalSecret key.
- **Worker code:** `worker/ragots.js` grows a router, the fossoyeur and a MIME body parser; unit tests grow with it. CI (`cloudflare-worker.yaml`) already runs them.
- **Band:** a short how-to mail on the main list once it is live.
