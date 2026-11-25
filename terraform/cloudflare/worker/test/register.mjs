// Node can't resolve the Workers-only cloudflare:email module: serve a stub instead
import { register } from "node:module";

register(
  "data:text/javascript," +
    encodeURIComponent(`
export async function resolve(specifier, context, next) {
  if (specifier === "cloudflare:email") return { url: "cloudflare-stub:email", shortCircuit: true };
  return next(specifier, context);
}
export async function load(url, context, next) {
  if (url === "cloudflare-stub:email") {
    return {
      format: "module",
      shortCircuit: true,
      source: "export class EmailMessage { constructor(from, to, raw) { Object.assign(this, { from, to, raw }); } }",
    };
  }
  return next(url, context);
}
`),
);
