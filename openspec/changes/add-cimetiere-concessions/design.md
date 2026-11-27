## Context

`cimetiere@mangococo.fr` (alias `ragots@`) is live: Email Routing sends both addresses to the `mangococo-ragots` Worker (`terraform/cloudflare/ragots.tf`, `worker/ragots.js`). A post from a member, checked on the envelope sender, is re-sent to every member through Cloudflare Email Sending as a new message from `Cimetière <cimetiere@mangococo.fr>`, with the headers that identify the sender removed. The 10 members live in the Bitwarden secret `ragots-members`, passed to the Worker as a `secret_text` binding, and only change through `scripts/ragots.py` plus a Terraform apply.

On the free plan, Email Sending only delivers to verified Email Routing destination addresses, so every member must click Cloudflare's verification email once.

## Goals / Non-Goals

**Goals:**

- Members let new people into the cimetière themselves, by email, and Julen hears about each entry.
- Members form private concessions inside the cimetière that only their members can see.
- Replies to a concession post go back to that concession, and members can tell which concession a mail came from.
- Members see who is in the cimetière and in their own concessions, by nickname.
- Every member list lives in Workers KV; nothing in Bitwarden, git or the Terraform state.
- Free tier only, all in `terraform/cloudflare`.

**Non-Goals:**

- **`contact@mangococo.fr`: do not touch it.** Its Worker (`worker/email-forward.js`), rule and Bitwarden map stay as they are. The only zone-wide change here, subaddressing, leaves it as it is today (see below).
- Protection against forged senders: usability first, a forged member address can act as that member.
- Hiding concessions from the Cloudflare account owner: Julen can always open KV in the dashboard. The tools built here never show concessions to him (see Privacy).
- Archives, digests, moderation, a web interface.

## Decisions

### Cimetière and concessions

| | Cimetière | Concession |
| --- | --- | --- |
| Address | `cimetiere@` (alias `ragots@`) | `cimetiere+<name>@` |
| Who is in it | The whole band | Some cimetière members |
| How you get in | A cimetière member buries you (`enterrer cimetiere`) | A member of that concession buries you (`enterrer <name>`); you must already be in the cimetière |
| Who is told | Julen, on every entry, verification and exit | Nobody outside the concession |
| Who can see it | Every cimetière member (`registre`) | Its members only; for everyone else it does not exist |
| Created by | Exists once | Any cimetière member (`acheter`) |
| Leaving | `exhumer cimetiere` also leaves every concession | `exhumer <name>`; the last one out frees the name |

Concession members must be cimetière members. So every new person enters through the cimetière, where Cloudflare verification and Julen's notice happen, and concessions never involve Cloudflare or Julen.

### Concession addresses use `+`

Cloudflare's subaddressing (`support_subaddress` on `cloudflare_email_routing_settings`) only understands `+`: with it on, `cimetiere+apero@` matches the existing literal `cimetiere@` rule, so concessions need no routing change at runtime. `+` is also the separator people know from Gmail, and every mail client accepts it.

Alternatives considered:

| Option | Why not |
| --- | --- |
| `cimetiere-apero@` or `cimetiere.apero@` | Not subaddressing: the Worker would create one routing rule per concession through the API (more token rights, a 200-rule cap, cleanup on deletion) |
| `apero@cimetiere.mangococo.fr` | Email Routing on a subdomain needs its own MX setup, and the API marks subdomain routing deprecated |
| `apero@mangococo.fr` through the catch-all | Concession names would compete with real addresses, and every spam address would reach the Worker |

Effect on `contact@`: with subaddressing on, `contact+x@` reaches the `contact@` Worker, which rejects it because `contact+x@` is not in its map. Today the disabled catch-all rejects it. Same outcome, no change to that Worker. `ragots+x@` is rejected by the router.

### One Worker, routed by recipient

`mangococo-ragots` keeps serving `cimetiere@` and `ragots@`, and gains `cimetiere+<name>@` and `fossoyeur@` (one more address in the `ragots` rule set). The cimetière and the concessions share the anonymising re-send and loop protection; `fossoyeur@` goes to the command handler.

### A concession answers as itself

Each copy of a concession post carries:

| Header | Value |
| --- | --- |
| `From` | `Cimetière · apero <cimetiere+apero@mangococo.fr>` |
| `Reply-To`, `To` | `cimetiere+apero@mangococo.fr` |
| `List-Id` | `apero.cimetiere.mangococo.fr` |
| `Subject` | the original subject prefixed with `[apero]`, once (not doubled on replies) |

The cimetière keeps today's headers.

The `send_email` binding allows a single sender today, `cimetiere@`, and concessions appear at runtime. Preferred: drop `allowed_sender_addresses` (Email Sending still only signs for `mangococo.fr`). If Email Sending refuses a plus address as sender, fall back to `From: Cimetière · apero <cimetiere@mangococo.fr>` with `Reply-To: cimetiere+apero@mangococo.fr`; replies still reach the concession.

### KV layout

One namespace, `mangococo-cimetiere`, created empty by Terraform and written by the Worker. Addresses are lowercased.

| Key | Value |
| --- | --- |
| `cimetiere` | the cimetière: `[{"address", "buriedBy", "buriedAt"}]` |
| `concession:<name>` | `{"members": [addresses], "boughtAt": "2026-11-27"}` (no buyer kept) |
| `concessions-of:<address>` | names of the concessions that address belongs to |
| `surnom:<address>` | that member's nickname |
| `surnom-index:<nickname>` | the address holding that nickname (nicknames are unique) |
| `pending` | addresses buried in the cimetière and not verified yet, with burial date |

Nicknames sit in the same namespace under their own prefix: one binding, same lifecycle as the members they describe. KV is eventually consistent (about 60 s) and has no transactions; a post right after a burial can miss the newcomer, and two commands at the same second on the same list can lose one write. Acceptable at band scale.

### Nicknames

Every cimetière member has a `surnom`: 2 to 24 characters, letters (accents allowed), digits, space and `-`, unique ignoring case and accents. It is given at burial in the cimetière and changed by its owner with `surnom <nouveau>`. The migrated members start with the part of their address before `@` until they choose one. Registers show `surnom <adresse>`, and `enterrer <concession>` accepts a nickname instead of an address.

### The fossoyeur speaks cemetery, in French

Commands go in the mail body, one per line; the subject is ignored; matching ignores case and accents.

| Command | Meaning | Who |
| --- | --- | --- |
| `enterrer cimetiere <adresse> <surnom>` | Let someone into the cimetière | Cimetière members |
| `enterrer <concession> <surnom ou adresse>` | Invite a cimetière member into a concession | Members of that concession |
| `exhumer cimetiere` | Leave the cimetière and every concession | Cimetière members |
| `exhumer <concession>` | Leave a concession; the last one out frees it | Members of that concession |
| `acheter <concession>` | Create a concession, with you as its first member | Cimetière members |
| `registre` | List the cimetière's members | Cimetière members |
| `registre <concession>` | List a concession's members | Members of that concession |
| `plan` | List your concessions | Cimetière members |
| `surnom <nouveau surnom>` | Change your nickname | Cimetière members |
| `aide` | The help text | Anyone |

One person per `enterrer` line. Any line that is not a command makes the whole answer the help text, quoting that line, and runs nothing. Reading stops at a signature (`-- `) or a quoted line (`>`). At most 10 commands per mail. A concession name is 2 to 32 characters of `a-z`, `0-9` and `-`; `cimetiere`, `ragots`, `fossoyeur` and `contact` are reserved.

The fossoyeur answers with `message.reply()`, which can reach a sender who is not a verified address. Implementation confirms the conditions `reply()` puts on the incoming mail (DMARC).

### Privacy of concessions

A concession is invisible to anyone outside it, Julen included:

- Every refusal about a concession you are not in reads exactly as if it did not exist: posting to it, `registre`, `enterrer`, `exhumer`.
- `plan` lists only your own concessions; nothing lists all of them.
- Julen gets no notification about concessions, and `scripts/cimetiere.py` has no command that reads them.
- The Worker logs no concession name or member.
- One leak is left: `acheter` on a taken name has to fail, and says "nom indisponible", the same answer as for a reserved name. Someone probing names learns that a name is in use, not who is in it.

### Mail bodies are parsed with postal-mime

Command mails arrive multipart, quoted-printable or base64, in charsets that depend on the client (Gmail, Hotmail, Yahoo, free.fr, La Poste). `postal-mime` is a dependency-free MIME parser written for Workers. Its ES modules are vendored under `worker/vendor/postal-mime/` and uploaded beside `ragots.js` through the script's `files` attribute, so Terraform still uploads files as they are and Burrito needs no build.

Rejected: an esbuild bundle (a committed build artefact to keep in sync); a hand-written parser (the first unusual client breaks it).

### Registration, welcome and notifications happen at cimetière level

`enterrer cimetiere` registers the address with `POST /accounts/{id}/email/routing/addresses`, which makes Cloudflare send the verification email, and adds it to `pending`. The answer tells the member to warn the newcomer ("dis-lui de chercher le mail de Cloudflare, spams compris").

The Worker's token is a `cloudflare_account_token` limited to Email Routing Addresses read and write, created by Terraform and passed as a `secret_text` binding: never in git, Bitwarden or a plan; rotated with `terraform apply -replace`.

Cloudflare emits no "verified" event, so a `cloudflare_workers_cron_trigger` runs `scheduled()` every 15 minutes. With `pending` empty it stops after one KV read. Otherwise it asks the API which pending addresses are verified, sends each a welcome mail ("Bienvenue au cimetière", how to post, `aide`), and removes them from `pending`. After 30 days unverified, an address leaves `pending`.

Julen (`julen@loudnaround.org`, from a `plain_text` binding) gets one mail per cimetière entry (who buried whom), per verification, per address dropped after 30 days, and per `exhumer cimetiere`. Nothing about concessions.

### Admin access covers the cimetière only

`scripts/cimetiere.py` (uv script, same shape as `forwards.py`) reads and writes the cimetière through the Cloudflare API: list members, add, remove, set a nickname, `import` from `ragots-members`, `export`. Removing someone from the cimetière also removes them from every concession, without printing which.

## Risks / Trade-offs

- **Forged senders** can bury people or read registers as a member → accepted; every cimetière entry reaches Julen, who can undo it with the script.
- **Members writing from another address** (an alias, a Gmail dot variant) are refused → the refusal says to be buried under that address too.
- **Email Sending refuses plus-address senders** → fallback headers above.
- **Email Sending free allowance** is not known yet → check before rollout; a post costs one send per member.
- **Concession privacy depends on convention** for the account owner → stated in Non-Goals; tools and logs never show concessions.
- **KV races** → accepted at band scale.

## Migration Plan

1. Julen adds "Account API Tokens Write" and "Workers KV Storage Write" to the token in `cloudflare-api-token`.
2. PR 1: KV namespace, subaddressing, the Worker reading the cimetière from KV with a fallback to the `MEMBERS` binding while the key is missing, `scripts/cimetiere.py`. Apply.
3. `scripts/cimetiere.py import` copies the 10 members of `ragots-members` into `cimetiere`. A post to `cimetiere@` behaves as before.
4. PR 2: fossoyeur, concessions, nicknames, registration, cron trigger, Worker token. Remove `MEMBERS`, `var.ragots_members`, `scripts/ragots.py`, the `.envrc` export and the ExternalSecret key. Apply, then delete `ragots-members` from Bitwarden.
5. Test with Julen's addresses, then send the band the how-to.

Rollback: before step 4, reverting PR 1 restores the Bitwarden path. After it, `scripts/cimetiere.py export` gives the member list back.

## Open Questions

- Registers show `surnom <adresse>`: fine, or nicknames only, keeping addresses hidden from other members?
- Concession members must already be in the cimetière (proposed above): agreed?
- Should Julen also hear about `exhumer cimetiere` (proposed above), or only about entries?
