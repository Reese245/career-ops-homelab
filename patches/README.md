# Patches

Changes I run on top of career-ops **v1.34.0**, one file per change. All of them apply cleanly to a fresh `career-ops-v1.34.0` checkout (`git apply --check`).

On my server they live as commits on top of the release tag. Upgrading means checking out the new tag and cherry-picking them with a three-way merge; when upstream has solved the same problem, upstream's version wins (v1.34.0 made the scan timeout configurable, which replaced my hardcoded one).

| Patch | What it changes | Why |
|---|---|---|
| `01-per-task-model-routing` | Evaluations run with `--model sonnet --effort medium`, tailored resumes with `--model opus --effort high` | The web UI launched every job with the default model. Evaluations are high-volume and token-heavy; resumes are few and benefit from the stronger model. |
| `02-apply-line-3.0` | The report badge says "Recommended" from 3.0 instead of 4.0 | Matches my own apply threshold; the evaluator's wording is set in my (private) profile. |
| `03-scan-shuffle-company-sample` | Passes `--shuffle` to the ATS scanner | Without it, the scanner's company limit always took the alphabetically first boards, so every scan re-hit the same large employers. |
| `04-workday-transient-vs-structural-truncation` | Distinguishes a Workday board that was cut off by a temporary error (worth one retry) from one that hit a fixed bound (retrying repeats the same expensive split) | Scans were spending their time re-crawling boards that could never complete. Includes test updates. |
| `05-icims-server-rendered-jd` | For iCIMS postings, reads the `in_iframe=1` server-rendered page | iCIMS renders client-side; both a plain fetch and headless Chromium saw only the page shell, so job descriptions came back empty. |
| `06-portals-empty-title-filter` | Always writes a valid `title_filter` block when saving portals from the UI | An empty filter produced YAML the scanner failed on. |
| `07-apply-stream-double-close` | Makes closing the apply-flow event stream idempotent | Closing it twice threw `ERR_INVALID_STATE` and dropped the final event before the browser read it. |
| `08-apply-novnc-viewer` | The Apply button opens the noVNC viewer of the server's virtual display | The UI is reached through a reverse proxy; the form being filled lives on the server's virtual display. |
| `09-quick-evaluate-always-visible` | Always shows the paste-a-URL evaluation box on the home page | Upstream only showed it in some dashboard states. |

**Provenance.** 01 and 02 were written this week. 03–09 were made on the server earlier, with AI coding agents; 03, 05, 08 and 09 carry "Local patch" comments in the code. I didn't record whether 04, 06 or 07 started from an upstream issue or pull request, so treat those as possibly adapted from upstream work rather than original.
