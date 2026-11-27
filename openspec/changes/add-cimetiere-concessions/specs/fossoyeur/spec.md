## ADDED Requirements

### Requirement: Commands in the body
The fossoyeur SHALL read commands from the plain-text body of mail to `fossoyeur@mangococo.fr`, one per line, in French only, ignoring case and accents, ignoring the subject, and stopping at a signature line (`-- `) or the first quoted line (`>`). It SHALL answer every mail once, by reply, with one result line per command.

#### Scenario: Several commands
- **WHEN** a member sends `acheter apero` and `enterrer apero Ed` on two lines
- **THEN** one reply reports both results in order

#### Scenario: Reply to a fossoyeur mail
- **WHEN** a member answers a fossoyeur reply with `plan` above the quoted text
- **THEN** only `plan` runs

#### Scenario: Encoded mail
- **WHEN** the body arrives as quoted-printable, base64 or multipart with an HTML part
- **THEN** the commands are read from the decoded text

### Requirement: Help on anything not understood
The fossoyeur SHALL answer with the help text, quoting the first line it did not understand, when a mail holds no command or any line that is not a command, and SHALL run none of that mail's commands.

#### Scenario: Unknown word
- **WHEN** someone writes `creuser apero`
- **THEN** the reply quotes `creuser apero` and gives the help text, and nothing changes

#### Scenario: Outsider
- **WHEN** an address outside the cimetière sends any command other than `aide`
- **THEN** the reply is the help text and nothing changes

### Requirement: Entering the cimetière
`enterrer cimetiere <address> <nickname>` SHALL make the address a cimetière member with that nickname, when the sender is a cimetière member and the nickname is free, register the address as an Email Routing destination when Cloudflare does not know it, and notify Julen.

#### Scenario: New person
- **WHEN** a cimetière member sends `enterrer cimetiere ed@x.org Ed`
- **THEN** `ed@x.org` is a cimetière member nicknamed `Ed`, Cloudflare sends it a verification email, the reply tells the member to warn Ed, and Julen is told who buried whom

#### Scenario: Taken nickname
- **WHEN** the nickname is already used by another member
- **THEN** nothing changes and the reply asks for another nickname

### Requirement: Inviting into a concession
`enterrer <concession> <nickname or address>` SHALL add a cimetière member to the concession when the sender is a member of that concession. Julen SHALL NOT be notified.

#### Scenario: Invite by nickname
- **WHEN** a member of `apero` sends `enterrer apero Ed`
- **THEN** the member nicknamed `Ed` receives the next `apero` posts

#### Scenario: Not in the cimetière
- **WHEN** the person named is not a cimetière member
- **THEN** nothing changes and the reply says to bury them in the cimetière first

### Requirement: Leaving
`exhumer cimetiere` SHALL remove the sender from the cimetière and every concession, and notify Julen. `exhumer <concession>` SHALL remove the sender from that concession only, and SHALL free the name when the last member leaves. Members SHALL NOT be able to remove anyone else.

#### Scenario: Leaving a concession
- **WHEN** a member of `apero` sends `exhumer apero`
- **THEN** they no longer receive `apero` posts and stay in the cimetière

#### Scenario: Last member
- **WHEN** the only member of `apero` sends `exhumer apero`
- **THEN** `apero` no longer exists and its name can be bought again

### Requirement: Buying a concession
`acheter <concession>` SHALL create the concession with the sender as its only member, when the sender is a cimetière member and the name is valid (2 to 32 characters of `a-z`, `0-9`, `-`), not reserved (`cimetiere`, `ragots`, `fossoyeur`, `contact`) and not in use. Julen SHALL NOT be notified.

#### Scenario: New concession
- **WHEN** a cimetière member sends `acheter apero` and the name is free
- **THEN** `apero` exists with the sender as member and the reply gives `cimetiere+apero@mangococo.fr`

#### Scenario: Name in use or reserved
- **WHEN** someone sends `acheter apero` while `apero` exists, or `acheter fossoyeur`
- **THEN** nothing changes and both replies read "nom indisponible"

### Requirement: Registers and plan
`registre` SHALL list the cimetière's members with their nicknames, to cimetière members. `registre <concession>` SHALL list that concession's members with their nicknames, to its members only. `plan` SHALL list the sender's own concessions.

#### Scenario: Cimetière register
- **WHEN** a cimetière member sends `registre`
- **THEN** the reply lists every cimetière member as `nickname <address>`, marking those not verified yet

#### Scenario: Concession register
- **WHEN** a member of `apero` sends `registre apero`
- **THEN** the reply lists the members of `apero`

#### Scenario: Plan
- **WHEN** a member of `apero` and `velo` sends `plan`
- **THEN** the reply lists `apero` and `velo` with their addresses, and no other concession

### Requirement: Nicknames
Every cimetière member SHALL have a unique nickname (2 to 24 characters: letters with accents, digits, space, `-`; unique ignoring case and accents). `surnom <nickname>` SHALL change the sender's own nickname.

#### Scenario: Change of nickname
- **WHEN** a member sends `surnom Eddy` and `Eddy` is free
- **THEN** registers show `Eddy` for that member and `enterrer apero Eddy` reaches them

### Requirement: Welcome once verified
A cron trigger SHALL run the Worker every 15 minutes and, for each address buried in the cimetière that has become a verified destination, SHALL send it a welcome mail and notify Julen. An address still unverified 30 days after its burial SHALL stop being checked, and Julen SHALL be told.

#### Scenario: Newcomer verifies
- **WHEN** `ed@x.org`, buried in the cimetière, clicks the Cloudflare verification link
- **THEN** within 15 minutes Ed receives a welcome mail explaining how to post and how to use the fossoyeur, and Julen is told Ed is verified

#### Scenario: Nobody pending
- **WHEN** the cron runs and nobody is waiting for verification
- **THEN** the run makes no Cloudflare API call and sends nothing

### Requirement: Worker token made by Terraform
The token the Worker uses to register addresses SHALL be a `cloudflare_account_token` limited to Email Routing Addresses read and write on the account, created by Terraform and passed as a `secret_text` binding.

#### Scenario: Token never exposed
- **WHEN** `terraform plan` runs in `terraform/cloudflare`
- **THEN** the token value shows as sensitive and is in no file of the repo and no Bitwarden secret
