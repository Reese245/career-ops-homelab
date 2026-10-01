#!/usr/bin/env bash
set -u
# Debian cron ignores TZ for scheduling; cron fires at 14 and 15 UTC, run only at 10 ET
[ "${FORCE:-0}" = 1 ] || [ "$(TZ=America/New_York date +%H)" = 10 ] || exit 0
echo "=== $(date -Is) morning scan start"
cd "${CAREER_OPS_DIR:-$HOME/career-ops}"
export PATH="$HOME/.opencode/bin:/usr/local/bin:/usr/bin:/bin"
LOG=$(mktemp)

timeout 1800 claude -p "Run the career-ops scan mode, ALL levels. After the zero-token parsers/APIs, you MUST also run Level 3: use WebSearch for every search_queries entry with enabled: true and for every tracked company with scan_method: websearch (its scan_query), then verify new hits with the CLI extractor before adding them. Do not skip these or defer them as manual follow-up. When finished, output a short plain-text summary for a phone notification: how many new listings were found, then the top 5 with company, role, and fit score. Under 800 characters, no markdown." --model sonnet --permission-mode acceptEdits --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebFetch,WebSearch" </dev/null > "$LOG" 2>&1
RC=$?

if [ $RC -eq 0 ]; then
  SUMMARY=$(tail -c 1500 "$LOG")
else
  SUMMARY="Morning scan FAILED (exit $RC). Last output: $(tail -c 500 "$LOG")"
fi

curl -sS -m 15 -o /dev/null -w "ntfy HTTP %{http_code}\n" -H "Title: career-ops morning scan" -H "Tags: briefcase" -d "$SUMMARY" "${NTFY_URL:?set NTFY_URL, e.g. https://ntfy.example.com/career-ops}" 
echo "scan rc=$RC"
rm -f "$LOG"
