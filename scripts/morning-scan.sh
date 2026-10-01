#!/usr/bin/env bash
set -u
# Debian cron ignores TZ for scheduling; cron fires at 14 and 15 UTC, run only at 10 ET
[ "${FORCE:-0}" = 1 ] || [ "$(TZ=America/New_York date +%H)" = 10 ] || exit 0
echo "=== $(date -Is) morning scan start"
cd "${CAREER_OPS_DIR:-$HOME/career-ops}"
export PATH="$HOME/.opencode/bin:/usr/local/bin:/usr/bin:/bin"
LOG=$(mktemp)

# Level 0/2 (zero-token parsers + ATS APIs) runs here, outside Claude: it can exceed
# Claude's 5-minute Bash tool limit, which backgrounds it and ends a headless session.
mkdir -p batch/logs
SCANOUT="batch/logs/morning-scan-$(date +%Y%m%d-%H%M).txt"
timeout 900 node scan.mjs > "$SCANOUT" 2>&1
echo "scan.mjs rc=$? ($(wc -l < "$SCANOUT") lines) -> $SCANOUT"

timeout 1800 claude -p "Run the career-ops scan mode. Level 0/2 (node scan.mjs: local parsers + ATS APIs) has ALREADY been run for you; its full output is in $SCANOUT - read that file and do NOT run scan.mjs again. Now run Level 3: use WebSearch for every search_queries entry with enabled: true and for every tracked company with scan_method: websearch (its scan_query), dedupe against the pipeline and scan history, verify new hits with the CLI extractor, and add verified ones to the pipeline. Do not skip these, defer them, or run anything in the background. When finished, output a short plain-text summary for a phone notification: how many new listings were found (Level 0/2 plus Level 3), then the top 5 with company, role, and fit score. Under 800 characters, no markdown." --model sonnet --permission-mode acceptEdits --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebFetch,WebSearch" </dev/null > "$LOG" 2>&1
RC=$?

if [ $RC -eq 0 ]; then
  SUMMARY=$(tail -c 1500 "$LOG")
else
  SUMMARY="Morning scan FAILED (exit $RC). Last output: $(tail -c 500 "$LOG")"
fi

curl -sS -m 15 -o /dev/null -w "ntfy HTTP %{http_code}\n" -H "Title: career-ops morning scan" -H "Tags: briefcase" -d "$SUMMARY" "${NTFY_URL:?set NTFY_URL, e.g. https://ntfy.example.com/career-ops}" 
echo "scan rc=$RC"
rm -f "$LOG"
