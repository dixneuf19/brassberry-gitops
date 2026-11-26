## ADDED Requirements

### Requirement: Commands in the body
The fossoyeur SHALL read commands from the plain-text body of mail to `fossoyeur@mangococo.fr`, one per line, ignoring case and accents, ignoring the subject, and stopping at a signature line (`-- `) or the first quoted line (`>`). It SHALL answer every mail once, by reply, with one result line per command.

#### Scenario: Several commands
- **WHEN** a member sends `acheter apero` and `enterrer apero ed@x.org` on two lines
- **THEN** one reply reports both results in order

#### Scenario: Reply to a fossoyeur mail
- **WHEN** a member answers a fossoyeur reply with `plan` above the quoted text
- **THEN** only `plan` runs

#### Scenario: HTML-only or encoded mail
- **WHEN** the body arrives as quoted-printable, base64 or multipart with an HTML part
- **THEN** the commands are read from the decoded text

### Requirement: Help on anything not understood
The fossoyeur SHALL answer with the help text, quoting the first line it did not understand, when a mail holds no command or any line that is not a command, and SHALL run none of that mail's commands.

#### Scenario: Unknown word
- **WHEN** someone writes `creuser apero`
- **THEN** the reply quotes `creuser apero` and gives the help text, and nothing changes

#### Scenario: Empty mail
- **WHEN** someone sends a mail with an empty body
- **THEN** the reply is the help text

### Requirement: acheter
`acheter <concession>` SHALL create the concession with the sender as its only member, when the name is free, valid (2 to 32 characters of `a-z`, `0-9`, `-`) and not reserved (`cimetiere`, `ragots`, `fossoyeur`, `contact`). Anyone MAY run it.

#### Scenario: New concession
- **WHEN** anyone sends `acheter apero` and `apero` does not exist
- **THEN** `apero` exists with the sender as member, the reply gives its address `cimetiere+apero@mangococo.fr`, and Julen is notified

#### Scenario: Taken or invalid name
- **WHEN** someone sends `acheter apero` while `apero` exists, or `acheter Apéro!`
- **THEN** nothing changes and the reply says why

### Requirement: enterrer
`enterrer <concession> <address> [<address> ...]` SHALL add the addresses to the concession when the sender is one of its members, and SHALL register every address not yet known to Cloudflare as an Email Routing destination address.

#### Scenario: New person
- **WHEN** a member of `apero` sends `enterrer apero ed@x.org` and Cloudflare does not know `ed@x.org`
- **THEN** `ed@x.org` is a member of `apero`, Cloudflare sends it a verification email, the reply tells the member to warn Ed, and Julen is notified

#### Scenario: Already verified person
- **WHEN** the address is already a verified destination (a member of another concession, or of `contact@`)
- **THEN** it is added and receives the next post without any verification

#### Scenario: Not a member
- **WHEN** someone outside `apero` sends `enterrer apero ed@x.org`
- **THEN** nothing changes and the reply says only members can bury people there

### Requirement: exhumer
`exhumer <concession>` SHALL remove the sender from the concession. Members SHALL NOT be able to remove anyone else. The concession SHALL be deleted when its last member leaves.

#### Scenario: Leaving
- **WHEN** a member of `apero` sends `exhumer apero`
- **THEN** they no longer receive `apero` posts

#### Scenario: Last member
- **WHEN** the only member of `apero` sends `exhumer apero`
- **THEN** `apero` no longer exists and its name can be bought again

### Requirement: registre and plan
`registre <concession>` SHALL list the concession's members, marking those not verified yet, to its members only. `plan` SHALL list the concessions the sender belongs to.

#### Scenario: Member reads the register
- **WHEN** a member of `apero` sends `registre apero`
- **THEN** the reply lists every member and which ones still have to click the verification email

#### Scenario: Outsider asks for the register
- **WHEN** someone outside `apero` sends `registre apero`
- **THEN** the reply lists nobody

### Requirement: Julen is notified
The Worker SHALL mail `julen@loudnaround.org` once per concession bought and once per address buried, naming who did it, the concession and the address.

#### Scenario: Burial notification
- **WHEN** a member buries two addresses in one command
- **THEN** Julen receives a mail naming the member, the concession and both addresses

### Requirement: Worker token made by Terraform
The token the Worker uses to register addresses SHALL be a `cloudflare_account_token` limited to Email Routing Addresses read and write on the account, created by Terraform and passed as a `secret_text` binding.

#### Scenario: Token never exposed
- **WHEN** `terraform plan` runs in `terraform/cloudflare`
- **THEN** the token value shows as sensitive and is in no file of the repo and no Bitwarden secret
