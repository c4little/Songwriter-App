import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { MissingEnvError, PUBLIC_ENV_KEYS, SERVER_ENV_KEYS, readServerEnv } from "./env";

describe("readServerEnv", () => {
  it("returns every server variable when all are set", () => {
    const source = Object.fromEntries(SERVER_ENV_KEYS.map((k) => [k, `value-${k}`]));
    expect(readServerEnv(source).WORKER_SECRET).toBe("value-WORKER_SECRET");
  });

  it("lists every missing variable", () => {
    const err = (() => {
      try {
        readServerEnv({ WORKER_SECRET: "x" });
      } catch (e) {
        return e;
      }
      return undefined;
    })();
    expect(err).toBeInstanceOf(MissingEnvError);
    expect((err as MissingEnvError).missing).not.toContain("WORKER_SECRET");
    expect((err as MissingEnvError).missing).toContain("APP_BASE_URL");
  });

  it("treats empty strings as missing", () => {
    const source = Object.fromEntries(SERVER_ENV_KEYS.map((k) => [k, ""]));
    expect(() => readServerEnv(source)).toThrow(MissingEnvError);
  });
});

describe(".env.example", () => {
  it("documents every variable the web app reads", () => {
    const example = readFileSync(new URL("../../../.env.example", import.meta.url), "utf8");
    for (const key of [...PUBLIC_ENV_KEYS, ...SERVER_ENV_KEYS]) {
      expect(example).toMatch(new RegExp(`^${key}=`, "m"));
    }
  });
});
