#!/bin/bash
# jev-pr-risk.sh <owner/repo> <pr-number> — classify a PR's diff with Jev before auto-merge.
#
# Prints one JSON object:
#   {"risky": true|false, "flags": ["shared billing (file.js)", ...], "files": N, "scored": N,
#    "unscored": [...], "per_file": {"path": {"billing":p,"migration":p,"auth":p,"behavior":p,"config":p}}}
# Exit 0 always; on failure prints {"risky": null, "error": "..."} so the caller decides.
#
# Used by pr-babysitter-hook.sh: a risky PR is still marked ready + announced on Slack, but
# auto-merge is NOT enabled and the Slack line says what to double-check. Enforces the standing
# rule that billing_service is shared across all tenants and changes must be provably non-breaking.
set -uo pipefail
REPO="${1:?owner/repo}"; PR="${2:?pr number}"
command -v jev-ask >/dev/null 2>&1 || PATH="$HOME/.local/bin:$PATH"

DIFF_FILE=$(mktemp -t jev-pr-diff) || exit 0
trap 'rm -f "$DIFF_FILE"' EXIT
gh pr diff "$PR" --repo "$REPO" > "$DIFF_FILE" 2>/dev/null || { echo '{"risky": null, "error": "gh pr diff failed"}'; exit 0; }
[ -s "$DIFF_FILE" ] || { echo '{"risky": false, "flags": [], "files": 0, "scored": 0, "unscored": [], "per_file": {}}'; exit 0; }

# The script arrives on stdin (heredoc), so the diff is passed as a file, not piped.
python3 - "$REPO" "$PR" "$DIFF_FILE" <<'EOF'
import json, os, re, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor

repo, pr, diff_file = sys.argv[1], sys.argv[2], sys.argv[3]
files, cur = {}, None
for line in open(diff_file, errors="replace").read().splitlines():
    if line.startswith("diff --git"):
        m = re.search(r" b/(\S+)$", line)
        cur = m.group(1) if m else None
        if cur:
            files[cur] = []
    elif cur and line[:1] in "+-" and not line.startswith(("+++", "---")):
        files[cur].append(line)
SKIP = re.compile(r"(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|\.snap$|\.min\.js$|/dist/|/build/|\.svg$|\.png$)")
files = {f: h for f, h in files.items() if h and not SKIP.search(f)}

QUESTIONS = {
    "billing": {"type": "noul", "instructions": "Does the CHANGE alter billing, subscription, plan, invoice, Stripe, credit, quota, reload or payment logic that runs for every tenant, or the shared billing service?"},
    "migration": {"type": "noul", "instructions": "Does the CHANGE add or modify a database schema, migration, Prisma model, or data backfill?"},
    "auth": {"type": "noul", "instructions": "Does the CHANGE touch authentication, sessions, tokens, password reset, roles, permissions, RBAC or tenant isolation?"},
    "behavior": {"type": "noul", "instructions": "Does the CHANGE alter runtime behaviour that existing users could notice, as opposed to a refactor, rename, comment, test or formatting change?"},
    "config": {"type": "noul", "instructions": "Does the CHANGE modify deployment, CI, environment variables, feature flags, cron schedules or infrastructure configuration?"},
}
THRESH = {"billing": 0.6, "migration": 0.6, "auth": 0.6, "config": 0.7}
LABEL = {"billing": "shared billing", "migration": "schema/migration", "auth": "auth / RBAC", "config": "deploy/CI/config"}
with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as q:
    json.dump(QUESTIONS, q)
    QPATH = q.name


def score(item):
    path, hunk = item
    state = f"Pull request {repo}#{pr}. One file's diff (+ added, - removed).\nFILE: {path}\n\nCHANGE:\n" + "\n".join(hunk)[:9000]
    try:
        p = subprocess.run(["jev-ask", "--purpose", "pr-risk", "--deadline", "4000", "--questions-file", QPATH],
                           input=state, capture_output=True, text=True, timeout=6)
        if p.returncode != 0:
            return path, None
        a = json.loads(p.stdout)
        return path, {k: round(float((a.get(k) or {}).get("noul", 0)), 2) for k in QUESTIONS}
    except Exception:
        return path, None


try:
    items = sorted(files.items(), key=lambda kv: -len(kv[1]))[:40]   # the 40 largest files
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = dict(pool.map(score, items))
finally:
    os.unlink(QPATH)
scored = {k: v for k, v in results.items() if v}
flags = []
for key, th in THRESH.items():
    hits = [f for f, v in scored.items() if v[key] >= th]
    if hits:
        flags.append(f"{LABEL[key]} ({', '.join(h.split('/')[-1] for h in hits[:3])}{'…' if len(hits) > 3 else ''})")
print(json.dumps({"risky": bool(flags), "flags": flags, "files": len(files), "scored": len(scored),
                  "unscored": [f for f in results if not results[f]], "per_file": scored}))
EOF
