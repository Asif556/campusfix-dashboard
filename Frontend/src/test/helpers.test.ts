import { describe, it, expect } from "vitest";
import { safeParse } from "../lib/storage";
import { resolvePhotoUrl, API_ORIGIN } from "../services/api";

describe("safeParse", () => {
  it("parses valid JSON", () => {
    expect(safeParse<{ a: number }>('{"a":1}')).toEqual({ a: 1 });
  });

  it("returns null for missing, empty, or corrupt values (never throws)", () => {
    expect(safeParse(null)).toBeNull();
    expect(safeParse("")).toBeNull();
    expect(safeParse("undefined")).toBeNull(); // the literal string JSON.stringify(undefined) produces
    expect(safeParse("null")).toBeNull();
    expect(safeParse("{not valid json")).toBeNull();
  });
});

describe("resolvePhotoUrl", () => {
  it("returns null when there is no photo", () => {
    expect(resolvePhotoUrl(null)).toBeNull();
    expect(resolvePhotoUrl(undefined)).toBeNull();
    expect(resolvePhotoUrl("")).toBeNull();
  });

  it("builds an absolute /campusfix/uploads URL from a stored relative path", () => {
    expect(resolvePhotoUrl("/uploads/abc.jpg")).toBe(`${API_ORIGIN}/campusfix/uploads/abc.jpg`);
  });

  it("passes an already-absolute URL through unchanged", () => {
    const url = "https://cdn.example.com/x.png";
    expect(resolvePhotoUrl(url)).toBe(url);
  });
});
