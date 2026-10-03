import { describe, expect, it } from "vitest";
import fixtures from "@shared/chord_fixtures.json";

// Phase 0 only checks the fixture file's shape. Phase 1 adds the parser and
// asserts that every case parses (or is rejected) as listed.
describe("shared/chord_fixtures.json", () => {
  it("has valid and invalid cases", () => {
    expect(fixtures.version).toBe(1);
    expect(fixtures.valid.length).toBeGreaterThan(0);
    expect(fixtures.invalid.length).toBeGreaterThan(0);
  });

  it("gives every valid case an input, canonical form and root", () => {
    for (const c of fixtures.valid) {
      expect(c.input).not.toBe("");
      expect(c.canonical).not.toBe("");
      expect(c.root).toMatch(/^[A-G][#b]?$/);
    }
  });

  it("has no input listed as both valid and invalid", () => {
    const valid = new Set(fixtures.valid.map((c) => c.input));
    for (const input of fixtures.invalid) {
      expect(valid.has(input)).toBe(false);
    }
  });
});
