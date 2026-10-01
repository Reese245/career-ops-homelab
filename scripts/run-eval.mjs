// Run career-ops' official headless evaluation against a job description that
// was saved by hand (for postings behind bot protection or JS-only pages).
// It reuses the web UI's own prompt builder and argv (so model routing and the
// tool allowlist match a normal web run) and tells the agent to read the saved
// file instead of fetching the URL.
//
// Usage:
//   CAREER_OPS_DIR=~/career-ops POSTED_AT=2026-09-22 OUT=/tmp/eval.jsonl \
//     node run-eval.mjs <posting-url> <saved-jd.md>
import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";

const root = path.resolve(process.env.CAREER_OPS_DIR || path.join(process.env.HOME, "career-ops"));
const { buildPrompt } = await import(path.join(root, "web/src/lib/run-prompts.mjs"));
const { claudeCliArgs } = await import(path.join(root, "web/src/lib/claude-invocation.mjs"));

const [url, jdPath] = process.argv.slice(2);
if (!url || !jdPath) {
  console.error("usage: node run-eval.mjs <posting-url> <saved-jd.md>");
  process.exit(1);
}

// Same durable notes the web UI passes (the managed block in modes/_profile.md).
const START = "<!-- co-web-notes:start -->";
const END = "<!-- co-web-notes:end -->";
let memory = "";
try {
  const md = fs.readFileSync(path.join(root, "modes/_profile.md"), "utf8");
  const i = md.indexOf(START), j = md.indexOf(END);
  if (i !== -1 && j > i) memory = md.slice(i + START.length, j).trim();
} catch {}

const today = new Date().toISOString().slice(0, 10);
let prompt = buildPrompt({ kind: "evaluate", input: url, memory, today, postedAt: process.env.POSTED_AT || null, lang: undefined });
const rel = path.relative(root, path.resolve(jdPath));
prompt += `\n\nPOSTING TEXT ALREADY RETRIEVED: The posting URL could not be fetched headlessly, so the full job description was saved verbatim to ${rel}. Do NOT WebFetch the URL. Read that file instead; it IS the posting text (header "Verification: unconfirmed (batch mode)" still applies). Keep the Posting URL above as the tracker url field.\n`;

const args = claudeCliArgs({ kind: "evaluate", prompt });
const out = fs.createWriteStream(process.env.OUT || "/tmp/eval.jsonl");
const child = spawn("claude", args, { cwd: root, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
child.stdout.pipe(out);
child.stderr.pipe(process.stderr);
child.on("close", (code) => console.error("exit", code));
