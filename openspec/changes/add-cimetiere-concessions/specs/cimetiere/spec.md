## ADDED Requirements

### Requirement: Concession addresses
Mail to `cimetiere+<concession>@mangococo.fr` SHALL reach the `mangococo-ragots` Worker through the existing `cimetiere@` rule, with subaddressing enabled on the zone.

#### Scenario: Known concession
- **WHEN** a mail arrives for `cimetiere+apero@mangococo.fr` and the concession `apero` exists
- **THEN** the Worker handles it as a post to `apero`

#### Scenario: Unknown concession
- **WHEN** a mail arrives for `cimetiere+nope@mangococo.fr` and no concession `nope` exists
- **THEN** the mail is rejected with a message naming `fossoyeur@mangococo.fr`

### Requirement: Members-only posting
The Worker SHALL accept a post to the main cimetière or a concession only when the envelope sender, lowercased, is one of its members, and SHALL re-send it to every member, sender included.

#### Scenario: Member posts
- **WHEN** a member of `apero` writes to `cimetiere+apero@mangococo.fr`
- **THEN** every member of `apero` receives a copy and nobody else does

#### Scenario: Non-member posts
- **WHEN** an address that is not a member of `apero` writes to `cimetiere+apero@mangococo.fr`
- **THEN** the mail is rejected with a message saying the address is not buried in `apero` and how to be

#### Scenario: Automated mail
- **WHEN** an auto-reply, a bounce or a mail carrying the cimetière loop header arrives
- **THEN** it is rejected and not re-sent

### Requirement: Anonymous copies
Copies SHALL carry the original subject, MIME headers and body, and SHALL drop every header that identifies the sender (From, Sender, Received, Message-ID, DKIM and ARC signatures, Return-Path), as the main list does today.

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

#### Scenario: Main list unchanged
- **WHEN** a member posts to `cimetiere@mangococo.fr` or `ragots@mangococo.fr`
- **THEN** the copies look exactly as they do before this change

### Requirement: Members stored in Workers KV
The members of the main cimetière and of every concession SHALL live in the `mangococo-cimetiere` KV namespace, under `concession:<name>`, with the main list as the reserved name `cimetiere`. No member address SHALL be stored in git, in Bitwarden or in the Terraform state.

#### Scenario: Migration
- **WHEN** the change is rolled out
- **THEN** the 10 addresses of the Bitwarden secret `ragots-members` are in `concession:cimetiere` and the secret is deleted

#### Scenario: Admin edit
- **WHEN** Julen runs `scripts/cimetiere.py` to remove an address from a concession
- **THEN** the next post to that concession no longer reaches it

### Requirement: Subaddressing does not break contact@
`contact+<anything>@mangococo.fr` SHALL be forwarded as `contact@mangococo.fr` is.

#### Scenario: Plus address on contact
- **WHEN** a mail arrives for `contact+site@mangococo.fr`
- **THEN** it reaches the same mailboxes as `contact@mangococo.fr`
