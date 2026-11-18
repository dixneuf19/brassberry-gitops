// Mailing list ragots@mangococo.fr: a message from a member (envelope sender
// in the MEMBERS secret binding, JSON list) goes to every member, sender
// included. Anything else is rejected.
const LOOP_HEADER = "X-Ragots-Loop";

export default {
  async email(message, env) {
    const members = JSON.parse(env.MEMBERS).map((m) => m.toLowerCase());

    if (message.headers.has(LOOP_HEADER)) {
      message.setReject("Message already went through this list");
      return;
    }
    if (!members.includes(message.from.toLowerCase())) {
      message.setReject("Only members can post to this list");
      return;
    }

    const headers = new Headers({ [LOOP_HEADER]: "1" });
    const results = await Promise.allSettled(members.map((m) => message.forward(m, headers)));
    const failures = results.filter((r) => r.status === "rejected");
    for (const failure of failures) {
      console.error("forward failed:", failure.reason);
    }
    if (failures.length === results.length) {
      throw new Error(`all ${results.length} forwards failed`);
    }
  },
};
