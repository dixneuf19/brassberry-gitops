import assert from "node:assert/strict";
import { test } from "node:test";
import worker from "../ragots.js";

const BODY = [
  "--000000000000b1",
  "Content-Type: text/plain; charset=UTF-8",
  "",
  "Ci-gît le café. Julen",
  "--000000000000b1--",
  "",
].join("\r\n");

const RAW = [
  "Received: from mail-wr1.google.com (209.85.221.1) by mx.cloudflare.net",
  "DKIM-Signature: v=1; a=rsa-sha256; d=loudnaround.org; s=google;",
  "\tb=abcdef",
  "From: Julen D <julen@loudnaround.org>",
  "To: cimetiere@mangococo.fr",
  "Subject: =?UTF-8?Q?Premi=C3=A8re_=C3=A9pitaphe?=",
  "Message-ID: <CAxyz@mail.gmail.com>",
  "In-Reply-To: <abc@mangococo.fr>",
  "References: <CAold@mail.gmail.com>",
  " <abc@mangococo.fr>",
  "MIME-Version: 1.0",
  'Content-Type: multipart/alternative; boundary="000000000000b1"',
  "",
  BODY,
].join("\r\n");

const MEMBERS = ["julen@loudnaround.org", "Elise@yahoo.fr"];

function incoming(from, headers = {}) {
  return {
    from,
    raw: new Blob([RAW]).stream(),
    headers: new Headers(headers),
    rejected: undefined,
    setReject(reason) {
      this.rejected = reason;
    },
  };
}

async function run(message) {
  const sent = [];
  const env = {
    MEMBERS: JSON.stringify(MEMBERS),
    SEND: {
      async send(m) {
        sent.push({ from: m.from, to: m.to, text: await new Response(m.raw).text() });
      },
    },
  };
  await worker.email(message, env);
  return sent;
}

const headerBlock = (text) => text.slice(0, text.indexOf("\r\n\r\n"));

test("a member's message goes to every member from the list address", async () => {
  const sent = await run(incoming("julen@loudnaround.org"));
  assert.deepEqual(sent.map((s) => s.to), ["julen@loudnaround.org", "elise@yahoo.fr"]);
  assert.ok(sent.every((s) => s.from === "cimetiere@mangococo.fr"));
});

test("headers keep nothing that identifies the sender", async () => {
  const [first] = await run(incoming("julen@loudnaround.org"));
  assert.doesNotMatch(headerBlock(first.text), /loudnaround|gmail|209\.85|Julen/);
  assert.match(first.text, /^Subject: =\?UTF-8\?Q\?Premi=C3=A8re_=C3=A9pitaphe\?=$/m);
  assert.match(first.text, /^From: .* <cimetiere@mangococo\.fr>$/m);
  assert.match(first.text, /^References: <abc@mangococo\.fr>$/m);
});

test("the body is passed through untouched", async () => {
  const [first] = await run(incoming("julen@loudnaround.org"));
  assert.ok(first.text.endsWith(`\r\n\r\n${BODY}`));
});

test("every copy shares one Message-ID", async () => {
  const sent = await run(incoming("julen@loudnaround.org"));
  const ids = sent.map((s) => s.text.match(/^Message-ID: (.*)$/m)?.[1]);
  assert.match(ids[0], /@mangococo\.fr>$/);
  assert.equal(new Set(ids).size, 1);
});

test("membership is case-insensitive", async () => {
  const message = incoming("ELISE@yahoo.fr");
  const sent = await run(message);
  assert.equal(message.rejected, undefined);
  assert.equal(sent.length, 2);
});

test("non-members are rejected", async () => {
  const message = incoming("stranger@example.org");
  assert.deepEqual(await run(message), []);
  assert.equal(message.rejected, "Only members can post to this list");
});

for (const headers of [{ "Auto-Submitted": "auto-replied" }, { Precedence: "bulk" }, { "X-Cimetiere-Loop": "1" }]) {
  test(`automated messages are rejected (${Object.keys(headers)[0]})`, async () => {
    const message = incoming("julen@loudnaround.org", headers);
    assert.deepEqual(await run(message), []);
    assert.equal(message.rejected, "Automated messages are not sent to this list");
  });
}
