import test from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const files = [
  ...readdirSync(root).filter((f) => f.endsWith(".ts")).map((f) => path.join(root, f)),
  ...readdirSync(path.join(root, "examples")).filter((f) => f.endsWith(".ts")).map((f) => path.join(root, "examples", f)),
];

// Regression: a cron example written as "*/15 * * * *" inside a block comment closes the comment at "*/".
for (const f of files) {
  test(`parses: ${path.relative(root, f)}`, () => {
    assert.doesNotThrow(() => stripTypeScriptTypes(readFileSync(f, "utf8")));
  });
}
