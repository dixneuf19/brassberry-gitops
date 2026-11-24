// Anonymous mailing list cimetiere@mangococo.fr (alias ragots@mangococo.fr).
// A message from a member (envelope sender in the MEMBERS secret binding,
// JSON list) is re-sent to every member, sender included, as a new message
// from the list address. The original headers that could identify the sender
// are dropped; the body is passed through untouched. Anything else is rejected.
import { EmailMessage } from "cloudflare:email";

const LIST_ADDRESS = "cimetiere@mangococo.fr";
const LIST_NAME = "Cimetière";
const LIST_DOMAIN = "mangococo.fr";
const LOOP_HEADER = "X-Cimetiere-Loop";

// Headers copied from the original message; everything else is dropped.
const KEPT_HEADERS = new Set(["subject", "mime-version", "content-type", "content-transfer-encoding"]);
// Threading headers, kept but filtered to the list's own message IDs.
const THREAD_HEADERS = new Set(["in-reply-to", "references"]);

// One char per byte, so the header block round-trips exactly whatever its encoding.
const bytesToBinary = (bytes) => {
  let out = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    out += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return out;
};
const binaryToBytes = (str) => Uint8Array.from(str, (c) => c.charCodeAt(0));

const encodeWord = (text) => {
  const utf8 = new TextEncoder().encode(text);
  return `=?UTF-8?B?${btoa(bytesToBinary(utf8))}?=`;
};

function splitMessage(raw) {
  for (let i = 0; i + 3 < raw.length; i++) {
    if (raw[i] === 13 && raw[i + 1] === 10 && raw[i + 2] === 13 && raw[i + 3] === 10) {
      return [raw.subarray(0, i), raw.subarray(i + 4)];
    }
  }
  for (let i = 0; i + 1 < raw.length; i++) {
    if (raw[i] === 10 && raw[i + 1] === 10) {
      return [raw.subarray(0, i), raw.subarray(i + 2)];
    }
  }
  return [raw, new Uint8Array()];
}

// Returns [name, value] pairs, keeping folded continuation lines in the value.
function parseHeaders(block) {
  const headers = [];
  for (const line of bytesToBinary(block).split(/\r?\n/)) {
    if (/^[ \t]/.test(line) && headers.length > 0) {
      headers[headers.length - 1][1] += `\r\n${line}`;
    } else {
      const colon = line.indexOf(":");
      if (colon > 0) headers.push([line.slice(0, colon), line.slice(colon + 1).trimStart()]);
    }
  }
  return headers;
}

function rewriteHeaders(original, messageId) {
  const out = [];
  for (const [name, value] of original) {
    const lower = name.toLowerCase();
    if (KEPT_HEADERS.has(lower)) {
      out.push(`${name}: ${value}`);
    } else if (THREAD_HEADERS.has(lower)) {
      const ids = (value.match(/<[^>]+>/g) || []).filter((id) => id.endsWith(`@${LIST_DOMAIN}>`));
      if (ids.length > 0) out.push(`${name}: ${ids.join(" ")}`);
    }
  }
  if (!original.some(([name]) => name.toLowerCase() === "subject")) out.push("Subject: ");
  const listAddress = `${encodeWord(LIST_NAME)} <${LIST_ADDRESS}>`;
  out.push(
    `From: ${listAddress}`,
    `To: ${listAddress}`,
    `Reply-To: ${listAddress}`,
    `Message-ID: ${messageId}`,
    `Date: ${new Date().toUTCString().replace("GMT", "+0000")}`,
    `List-Id: ${encodeWord(LIST_NAME)} <${LIST_ADDRESS.replace("@", ".")}>`,
    `List-Post: <mailto:${LIST_ADDRESS}>`,
    "Precedence: list",
    `${LOOP_HEADER}: 1`,
  );
  return out.join("\r\n");
}

// Vacation replies and bounces sent back to the list must not be broadcast.
function isAutomated(headers) {
  const autoSubmitted = headers.get("Auto-Submitted");
  const precedence = (headers.get("Precedence") || "").toLowerCase();
  return (
    headers.has(LOOP_HEADER) ||
    (autoSubmitted !== null && autoSubmitted.toLowerCase() !== "no") ||
    ["bulk", "list", "junk"].includes(precedence)
  );
}

export default {
  async email(message, env) {
    const members = JSON.parse(env.MEMBERS).map((m) => m.toLowerCase());

    if (isAutomated(message.headers)) {
      message.setReject("Automated messages are not sent to this list");
      return;
    }
    if (!members.includes(message.from.toLowerCase())) {
      message.setReject("Only members can post to this list");
      return;
    }

    const raw = new Uint8Array(await new Response(message.raw).arrayBuffer());
    const [headerBlock, body] = splitMessage(raw);
    // Same ID for every copy, so replies thread for everyone
    const messageId = `<${crypto.randomUUID()}@${LIST_DOMAIN}>`;
    const headers = binaryToBytes(`${rewriteHeaders(parseHeaders(headerBlock), messageId)}\r\n\r\n`);
    const rebuilt = new Uint8Array(headers.length + body.length);
    rebuilt.set(headers);
    rebuilt.set(body, headers.length);

    const results = await Promise.allSettled(
      members.map((m) => env.SEND.send(new EmailMessage(LIST_ADDRESS, m, new Response(rebuilt).body))),
    );
    const failures = results.filter((r) => r.status === "rejected");
    for (const failure of failures) {
      console.error("send failed:", failure.reason);
    }
    if (failures.length === results.length) {
      throw new Error(`all ${results.length} sends failed`);
    }
  },
};
