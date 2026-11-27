## ADDED Requirements

### Requirement: Cimetière and concessions
The cimetière SHALL be the list shared by all its members, at `cimetiere@mangococo.fr` and `ragots@mangococo.fr`. A concession SHALL be a named sub-group of cimetière members at `cimetiere+<concession>@mangococo.fr`, reached through the existing `cimetiere@` rule with subaddressing enabled on the zone. Only cimetière members SHALL be members of a concession.

#### Scenario: Concession address
- **WHEN** a mail arrives for `cimetiere+apero@mangococo.fr`
- **THEN** the `mangococo-ragots` Worker handles it as a post to the concession `apero`

#### Scenario: Leaving the cimetière
- **WHEN** a member leaves the cimetière or is removed from it
- **THEN** they are also removed from every concession

### Requirement: Members-only posting
The Worker SHALL accept a post only when the envelope sender, lowercased, is a member of the cimetière or concession it is addressed to, and SHALL re-send it to every member, sender included.

#### Scenario: Member posts to a concession
- **WHEN** a member of `apero` writes to `cimetiere+apero@mangococo.fr`
- **THEN** every member of `apero` receives a copy and nobody else does

#### Scenario: Outsider posts to a concession
- **WHEN** an address that is not a member of `apero` writes to `cimetiere+apero@mangococo.fr`
- **THEN** the mail is rejected with exactly the message used for a concession that does not exist

#### Scenario: Automated mail
- **WHEN** an auto-reply, a bounce or a mail carrying the cimetière loop header arrives
- **THEN** it is rejected and not re-sent

### Requirement: Anonymous copies
Copies SHALL carry the original subject, MIME headers and body, and SHALL drop every header that identifies the sender (From, Sender, Received, Message-ID, DKIM and ARC signatures, Return-Path), as the cimetière does today.

#### Scenario: Sender hidden
- **WHEN** a member posts to a concession
- **THEN** no header of the copies contains the member's address

### Requirement: A concession answers as itself
Copies of a concession post SHALL be addressed so that replying reaches the same concession and the concession is visible in the mail client.

#### Scenario: Reply to a concession post
- **WHEN** a member clicks Reply on a copy from `apero`
- **THEN** the reply is addressed to `cimetiere+apero@mangococo.fr`

#### Scenario: Recognising the concession
- **WHEN** a member reads a copy from `apero`
- **THEN** the sender name reads `Cimetière · apero` and the subject starts with `[apero]`, once

#### Scenario: Cimetière unchanged
- **WHEN** a member posts to `cimetiere@mangococo.fr` or `ragots@mangococo.fr`
- **THEN** the copies look exactly as they do before this change

### Requirement: Concessions are invisible from outside
Nothing SHALL let someone outside a concession list it, read its members or learn who belongs to it: not the fossoyeur, not the admin script, not Julen's notifications, not the Worker logs. The only allowed signal is that `acheter` refuses a name in use with the same answer as a reserved name.

#### Scenario: Probing a concession
- **WHEN** someone outside `apero` posts to it, or sends `registre apero`, `enterrer apero ...` or `exhumer apero` to the fossoyeur
- **THEN** each answer is identical to the answer for a concession that does not exist

#### Scenario: Admin view
- **WHEN** Julen runs any `scripts/cimetiere.py` command
- **THEN** the output names no concession

### Requirement: Members and nicknames stored in Workers KV
The cimetière members, the concessions, the nicknames and the pending verifications SHALL live in the `mangococo-cimetiere` KV namespace. No member address SHALL be stored in git, in Bitwarden or in the Terraform state.

#### Scenario: Migration
- **WHEN** the change is rolled out
- **THEN** the 10 addresses of the Bitwarden secret `ragots-members` are cimetière members in KV, and the secret, `var.ragots_members` and `scripts/ragots.py` are gone

#### Scenario: Admin edit
- **WHEN** Julen runs `scripts/cimetiere.py rm ed@x.org`
- **THEN** the next post to the cimetière or to any concession no longer reaches `ed@x.org`

### Requirement: contact@ is untouched
This change SHALL NOT modify the `contact@mangococo.fr` rule, its Worker or its Bitwarden map.

#### Scenario: Plus address on contact
- **WHEN** a mail arrives for `contact+x@mangococo.fr` after subaddressing is enabled
- **THEN** it is rejected, as it is before this change
