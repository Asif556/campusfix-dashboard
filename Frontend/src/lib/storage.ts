/**
 * Safe localStorage JSON helpers.
 *
 * `JSON.parse(localStorage.getItem(key) || '{}')` only guards the *missing-key*
 * case — a malformed value (e.g. the literal string "undefined" written by
 * `JSON.stringify(undefined)`) still throws and can white-screen the app during
 * render. These helpers never throw.
 */

export function safeParse<T>(raw: string | null): T | null {
  if (raw === null || raw === '' || raw === 'undefined' || raw === 'null') {
    return null;
  }
  try {
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

/** Read and JSON-parse a localStorage key, returning null on missing/corrupt data. */
export function getStoredJSON<T>(key: string): T | null {
  return safeParse<T>(localStorage.getItem(key));
}
