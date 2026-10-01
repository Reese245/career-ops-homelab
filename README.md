# career-ops-homelab

How I run [career-ops](https://github.com/career-ops-hq/career-ops), an open-source AI job-search pipeline, as a self-hosted service in my homelab, and the changes I've made to it.

This repo is the operations layer, not a fork: scripts, patches, deployment config and the rules my AI agents follow. My resume, profile, tracker and evaluation reports stay private and are not here.

## What it does

- **Every morning** a scheduled job scans ~120 tracked companies (job-board APIs first, then targeted web search), filters by title and location, and pushes a summary to my phone via a self-hosted [ntfy](https://ntfy.sh) server.
- **Evaluations**: each promising posting gets a structured 1–5 evaluation against my resume (skills match, level, comp, posting legitimacy).
- **Tailored resumes**: for roles I apply to, it generates an ATS-friendly PDF from my base resume without inventing experience.
- **Tracker hygiene**: anything still "Evaluated" below my 3.0 apply line is moved to SKIP automatically.

## Architecture

```
Proxmox VM (Ubuntu)
├── career-ops core (git checkout, pinned to a release tag + my patch commits)
├── career-ops web UI (Next.js, `next start`) ── systemd: career-ops-web.service
├── cron 10:00 ET ── scripts/morning-scan.sh
│     ├── node scan.mjs                 (zero-token: ATS APIs + local parsers)
│     ├── claude -p … --model sonnet    (web-search level, verify, summarize)
│     ├── scripts/auto-skip-low-scores.sh
│     └── curl → ntfy                    (phone notification)
├── Headless Chromium on a virtual display (Xvfb) + noVNC viewer
└── Claude Code CLI (subscription auth, no API key)

Access: tailnet-only (Tailscale) behind a Caddy reverse proxy with Let's Encrypt certs (DNS-01).
```

### Model routing

Different tasks get different models, chosen per run in `claude-invocation.mjs` (see [patches/01](patches/01-per-task-model-routing.patch)):

| Task | Model | Effort | Why |
|---|---|---|---|
| Evaluations | `sonnet` | medium | High volume and token-heavy (30–40 tool calls each) |
| Tailored resumes | `opus` | high | Writing quality matters; fewer runs |
| Daily scan | `sonnet` | default | Mostly search and filtering |

Aliases are used on purpose, so updating Claude Code picks up new model versions without code changes.

## Repo layout

| Path | What |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Rules for AI agents working on this setup, including the ones added after an agent got something wrong |
| [`scripts/morning-scan.sh`](scripts/morning-scan.sh) | Daily scan → auto-skip → notification |
| [`scripts/auto-skip-low-scores.sh`](scripts/auto-skip-low-scores.sh) | Moves low-scoring "Evaluated" rows to SKIP via career-ops' own `set-status.mjs` |
| [`scripts/run-eval.mjs`](scripts/run-eval.mjs) | Runs the official evaluation against a saved job description (for postings behind bot protection) |
| [`patches/`](patches/) | My changes to career-ops, one file per change, applied on top of v1.34.0 |
| [`deploy/`](deploy/) | systemd unit for the web UI |

## Setup notes

Scripts read their locations from the environment:

```bash
export CAREER_OPS_DIR="$HOME/career-ops"
export NTFY_URL="https://ntfy.example.com/career-ops"
```

Apply the patches on a career-ops checkout:

```bash
cd "$CAREER_OPS_DIR"
git checkout -B main career-ops-v1.34.0
git apply /path/to/career-ops-homelab/patches/*.patch
cd web && npm ci && npm run build
```

## History

I ran this privately before publishing it. The commit history here was created in October 2026 and replays real earlier versions of the scan script in order; each commit message notes when the change was originally made.

## License

MIT for the files in this repo. career-ops itself is MIT-licensed by its authors.
