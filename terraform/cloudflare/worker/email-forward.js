// Forwards each message to every destination listed for its recipient in the
// FORWARDS secret binding (JSON: {"src@mangococo.fr": ["dest", ...]}).
export default {
  async email(message, env) {
    const forwards = JSON.parse(env.FORWARDS);
    const destinations = forwards[message.to.toLowerCase()];
    if (!destinations || destinations.length === 0) {
      message.setReject("Unknown address");
      return;
    }
    for (const destination of destinations) {
      await message.forward(destination);
    }
  },
};
