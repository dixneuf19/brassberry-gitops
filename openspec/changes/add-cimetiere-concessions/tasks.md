## 1. Prerequisites

- [ ] 1.1 Julen adds "Account API Tokens Write" and "Workers KV Storage Write" to the token in `cloudflare-api-token`
- [ ] 1.2 Check the Email Sending free allowance in the dashboard
- [ ] 1.3 Check whether Email Sending accepts `cimetiere+<name>@mangococo.fr` as sender, and the conditions of `message.reply()`; pick the header variant in design.md accordingly

## 2. Cimetière in KV (PR 1, terraform/cloudflare)

- [ ] 2.1 `cloudflare_workers_kv_namespace.cimetiere` and its binding on `cloudflare_workers_script.ragots`
- [ ] 2.2 `cloudflare_email_routing_settings` with `support_subaddress = true` (import the existing settings first); check that `contact+x@` is still rejected
- [ ] 2.3 `worker/ragots.js` reads the cimetière from the `cimetiere` key, falling back to the `MEMBERS` binding while the key is missing; tests
- [ ] 2.4 `scripts/cimetiere.py` (uv script): `list`, `add`, `rm`, `surnom`, `import` (from `ragots-members`, nicknames from the address), `export`; no concession command
- [ ] 2.5 `terraform plan` shows the namespace, the settings change and the Worker update, nothing else; apply
- [ ] 2.6 `scripts/cimetiere.py import`, then one post to `cimetiere@` reaches the 10 members as before

## 3. Fossoyeur and concessions (PR 2)

- [ ] 3.1 Vendor `postal-mime` under `worker/vendor/postal-mime/`, uploaded through the script's `files`; exclude it from `tsc`
- [ ] 3.2 Router on the recipient: cimetière, concession, fossoyeur; `ragots+x@` rejected
- [ ] 3.3 Concession posts: membership check, refusal identical to "does not exist", anonymous copies, concession headers (From, Reply-To, To, List-Id, `[name]` subject prefix)
- [ ] 3.4 Command parser (body, signature and quote cut-off, accents, 10-command cap) with unit tests on real mails from Gmail, Hotmail, Yahoo, free.fr and La Poste
- [ ] 3.5 `enterrer`, `exhumer`, `acheter`, `registre`, `plan`, `surnom`, `aide` with the KV indexes kept in sync; unit tests, including the privacy cases (outsiders get the "does not exist" answers)
- [ ] 3.6 Address registration through the Cloudflare API on `enterrer cimetiere`; `cloudflare_account_token.fossoyeur` and its `secret_text` binding
- [ ] 3.7 `pending` list, `scheduled()` handler and `cloudflare_workers_cron_trigger` every 15 minutes: welcome mail, notification, drop after 30 days; tests
- [ ] 3.8 Notifications to Julen for cimetière entries, verifications, drops and exits only (`plain_text` binding for the address); no concession data in logs
- [ ] 3.9 `fossoyeur@` added to the `ragots` rule set; `allowed_sender_addresses` changed per 1.3
- [ ] 3.10 Remove `MEMBERS`, `var.ragots_members`, `scripts/ragots.py`, the `.envrc` export and the ExternalSecret key; update `README.md` and `CLAUDE.md`
- [ ] 3.11 `terraform plan` shows no change to `contact@` resources; apply; delete `ragots-members` from Bitwarden

## 4. Acceptance

- [ ] 4.1 From `julen@loudnaround.org`: `enterrer cimetiere contact@loudnaround.org Test`, Julen's notification arrives, then the welcome mail within 15 minutes
- [ ] 4.2 `acheter test-tombe`, `enterrer test-tombe Test`: no notification to Julen
- [ ] 4.3 A post to `cimetiere+test-tombe@` reaches both, anonymised, from `Cimetière · test-tombe`; Reply goes back to the concession
- [ ] 4.4 From an address outside the concession: posting, `registre test-tombe` and `enterrer test-tombe` all answer as for a missing concession
- [ ] 4.5 `registre`, `registre test-tombe`, `plan`, `surnom`, and a nonsense mail behave as specified
- [ ] 4.6 `exhumer test-tombe` from both (the concession disappears), `exhumer cimetiere` from `contact@loudnaround.org` (Julen notified), then send the band the how-to on the cimetière
