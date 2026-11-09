import test from "node:test";
import assert from "node:assert/strict";
import { readdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const js = (dir) => readdirSync(path.join(root, dir)).filter((f) => f.endsWith(".js")).map((f) => path.join(root, dir, f));
const files = [...js("."), ...js("examples"), ...js("lib")];

test("no TypeScript sources are left: every handler is plain JavaScript", () => {
  const ts = [".", "examples", "lib"].flatMap((d) => readdirSync(path.join(root, d)).filter((f) => f.endsWith(".ts")));
  assert.deepEqual(ts, []);
});

// `node --check` parses without running, so files that import packages this repo does not install still pass.
// Regression: a cron example written as "*/15 * * * *" inside a block comment closes the comment at "*/".
for (const f of files) {
  test(`parses: ${path.relative(root, f)}`, () => {
    const r = spawnSync(process.execPath, ["--check", f], { encoding: "utf8" });
    assert.equal(r.status, 0, r.stderr);
  });
}
