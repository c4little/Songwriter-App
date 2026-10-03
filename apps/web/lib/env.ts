// Typed access to the environment variables in PRD section 14.
// Server-only values must never be imported into client components.

export const PUBLIC_ENV_KEYS = ["NEXT_PUBLIC_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_ANON_KEY"] as const;

export const SERVER_ENV_KEYS = [
  "SUPABASE_SERVICE_ROLE_KEY",
  "MODAL_ENDPOINT_URL",
  "WORKER_SECRET",
  "RENDER_TOKEN_SECRET",
  "APP_BASE_URL",
] as const;

export type PublicEnvKey = (typeof PUBLIC_ENV_KEYS)[number];
export type ServerEnvKey = (typeof SERVER_ENV_KEYS)[number];

export class MissingEnvError extends Error {
  readonly missing: readonly string[];

  constructor(missing: readonly string[]) {
    super(`Missing environment variables: ${missing.join(", ")}`);
    this.name = "MissingEnvError";
    this.missing = missing;
  }
}

type EnvSource = Readonly<Record<string, string | undefined>>;

function pick<K extends string>(keys: readonly K[], source: EnvSource): Record<K, string> {
  const missing = keys.filter((key) => !source[key]);
  if (missing.length > 0) {
    throw new MissingEnvError(missing);
  }
  return Object.fromEntries(keys.map((key) => [key, source[key] as string])) as Record<K, string>;
}

export function readPublicEnv(source: EnvSource = process.env): Record<PublicEnvKey, string> {
  return pick(PUBLIC_ENV_KEYS, source);
}

export function readServerEnv(source: EnvSource = process.env): Record<ServerEnvKey, string> {
  return pick(SERVER_ENV_KEYS, source);
}
