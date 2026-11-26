import { describe, it, expect } from "vitest";

describe("CI/CD Failure Demonstration", () => {
  it("intentionally fails to verify deployment prevention", () => {
    expect(1).toBe(2);
  });
});