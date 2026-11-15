// Forwards each message to every destination listed for its recipient in the
// FORWARDS secret binding (JSON: {"src@mangococo.fr": ["dest", ...]}).
// One failing destination (e.g. not verified yet) must not block the others.
export default {
  async email(message, env) {
    const forwards = JSON.parse(env.FORWARDS);
    const destinations = forwards[message.to.toLowerCase()];
    if (!destinations || destinations.length === 0) {
      message.setReject("Unknown address");
      return;
    }
    const results = await Promise.allSettled(destinations.map((d) => message.forward(d)));
    const failures = results.filter((r) => r.status === "rejected");
    for (const failure of failures) {
      console.error("forward failed:", failure.reason);
    }
    if (failures.length === results.length) {
      throw new Error(`all ${results.length} forwards failed`);
    }
  },
};
