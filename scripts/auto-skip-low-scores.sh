#!/usr/bin/env bash
# Local patch: move tracker rows still in "Evaluated" with a score below the
# apply line to SKIP, via set-status.mjs so each change lands in the status log.
# Usage: ./auto-skip-low-scores.sh [--dry-run]   (threshold: AUTO_SKIP_BELOW, default 3.0)
set -u
cd "${CAREER_OPS_DIR:-$HOME/career-ops}"
THRESHOLD="${AUTO_SKIP_BELOW:-3.0}"
DRY="${1:-}"
python3 - "$THRESHOLD" <<'PY' | while IFS=$'\t' read -r row score company; do
import re,sys
t=float(sys.argv[1])
for l in open('data/applications.md'):
    c=[x.strip() for x in l.strip().strip('|').split('|')]
    if len(c)>=6 and c[0].isdigit() and c[5].lower()=='evaluated':
        m=re.match(r'([\d.]+)/5',c[4])
        if m and float(m.group(1))<t: print(f"{c[0]}\t{m.group(1)}\t{c[2]}")
PY
  if [ "$DRY" = "--dry-run" ]; then
    echo "would skip #$row $company ($score)"
  else
    node set-status.mjs --row "$row" skip --note "auto-skip: score $score < $THRESHOLD" >/dev/null 2>&1 \
      && echo "skipped #$row $company ($score)" || echo "FAILED #$row $company ($score)"
  fi
done
