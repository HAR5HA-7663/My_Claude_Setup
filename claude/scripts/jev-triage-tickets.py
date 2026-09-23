#!/usr/bin/env python3
"""jev-triage-tickets.py — Jev hygiene pass over a board of tickets (Monday BMYT, GitHub issues...).

    python3 jev-triage-tickets.py tickets.json [--json]

tickets.json: list of {"id", "title", "body", "status"?, "area"?, "owner"?, "created"?}

Per ticket (batched 8 per request):
    severity        score  0 cosmetic · 1 minor · 2 major · 3 critical/outage/data
    area            choice billing | auth_rbac | crm | voice_sms | email | integrations | ui | infra_ci | data_migration | other
    missing_repro   noul   a bug report with no steps, expected/actual, or environment
    is_bug          noul   vs feature/chore
Then duplicate candidates: titles are grouped by area and every pair within an area is scored
`same_issue` in ONE request per area (the entity-alignment pattern), pairs >= 0.7 are reported.

Report only — never writes to the board. Hand the report to Claude to draft comments in
Harsha's voice for the "missing repro" ones and to propose duplicate merges.
"""

from __future__ import annotations

import itertools
import json
import os
import subprocess
import sys
import tempfile
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

BATCH = 8
AREAS = {
    "billing": "billing, subscriptions, plans, Stripe, credits, reloads, invoices, usage metering",
    "auth_rbac": "login, sessions, password reset, roles, permissions, tenant isolation",
    "crm": "contacts, pipeline, stages, leads, notes, CRM views, campaigns",
    "voice_sms": "calls, dialer, recordings, SMS, 10DLC, phone numbers, Teli integration",
    "email": "email sending, templates, sender setup, deliverability",
    "integrations": "third-party APIs, webhooks, GHL, Zapier, Tidalwave, marketplace vendors",
    "ui": "layout, styling, navigation, forms, dark mode, responsiveness",
    "infra_ci": "deploys, staging/prod environments, CI, cron jobs, performance, logging",
    "data_migration": "schema, migrations, backfills, data fixes, reports",
    "other": "none of the above",
}


def ask(state: str, questions: dict, deadline: int = 6000) -> dict:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as q:
        json.dump(questions, q); qpath = q.name
    try:
        r = subprocess.run(["jev-ask", "--purpose", "ticket-triage", "--deadline", str(deadline), "--questions-file", qpath],
                           input=state, capture_output=True, text=True, timeout=deadline / 1000 + 2)
        return json.loads(r.stdout) if r.returncode == 0 else {}
    except Exception:  # noqa: BLE001
        return {}
    finally:
        os.unlink(qpath)


def classify(batch: list[dict]) -> list[dict]:
    parts = ["Tickets from a software team's tracker. Judge each TICKET on its own."]
    qs = {}
    for i, t in enumerate(batch, 1):
        parts.append(f"TICKET {i} [{t.get('id')}] status={t.get('status', '?')}\nTITLE: {t.get('title', '')}\nBODY: {str(t.get('body', ''))[:1500]}")
        qs[f"t{i}_severity"] = {"type": "score", "instructions": f"How severe is TICKET {i}?", "criteria": [
            "Cosmetic, typo, nice-to-have", "Minor: a workaround exists, few users affected", "Major: a core flow is broken or wrong for many users", "Critical: outage, data loss or corruption, security, money charged wrongly"]}
        qs[f"t{i}_area"] = {"type": "choice", "instructions": f"Which area does TICKET {i} belong to?", "criteria": AREAS}
        qs[f"t{i}_is_bug"] = {"type": "noul", "instructions": f"Is TICKET {i} a bug report (something that should work does not), as opposed to a feature request, chore or question?"}
        qs[f"t{i}_missing_repro"] = {"type": "noul", "instructions": f"If TICKET {i} is a bug report, is it missing what is needed to reproduce it: concrete steps, the expected vs actual result, or which account/environment/page?"}
    a = ask("\n\n".join(parts), qs)
    out = []
    for i, t in enumerate(batch, 1):
        row = {"id": t.get("id"), "title": str(t.get("title", ""))[:90], "status": t.get("status")}
        try:
            row.update(severity=round(float(a[f"t{i}_severity"]["score"]), 2), area=a[f"t{i}_area"]["choice"],
                       is_bug=round(float(a[f"t{i}_is_bug"]["noul"]), 2), missing_repro=round(float(a[f"t{i}_missing_repro"]["noul"]), 2))
            row["needs_repro"] = row["is_bug"] >= 0.5 and row["missing_repro"] >= 0.6
        except (KeyError, TypeError, ValueError):
            row.update(area="unscored")
        out.append(row)
    return out


def duplicates(rows: list[dict], tickets: dict) -> list[dict]:
    by_area = defaultdict(list)
    for r in rows:
        if r.get("area") not in (None, "unscored"):
            by_area[r["area"]].append(r["id"])
    found = []
    for area, ids in by_area.items():
        pairs = list(itertools.combinations(ids, 2))
        if not pairs:
            continue
        for chunk_start in range(0, len(pairs), 60):   # ≤60 pairs per request keeps the state small
            chunk = pairs[chunk_start:chunk_start + 60]
            parts = [f"Tickets in the '{area}' area of one tracker. For each PAIR decide whether the two tickets describe the same underlying problem or request."]
            qs = {}
            for j, (x, y) in enumerate(chunk, 1):
                parts.append(f"PAIR {j}:\n  A [{x}]: {tickets[x].get('title', '')} — {str(tickets[x].get('body', ''))[:300]}\n  B [{y}]: {tickets[y].get('title', '')} — {str(tickets[y].get('body', ''))[:300]}")
                qs[f"p{j}"] = {"type": "noul", "instructions": f"Do the two tickets in PAIR {j} describe the same underlying issue or request (one could be closed as a duplicate of the other)?"}
            a = ask("\n\n".join(parts), qs, deadline=8000)
            for j, (x, y) in enumerate(chunk, 1):
                try:
                    p = float(a[f"p{j}"]["noul"])
                except (KeyError, TypeError, ValueError):
                    continue
                if p >= 0.7:
                    found.append({"a": x, "b": y, "p": round(p, 2), "area": area})
    return sorted(found, key=lambda d: -d["p"])


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__); return 2
    tickets_list = json.loads(Path(sys.argv[1]).read_text())
    tickets = {t["id"]: t for t in tickets_list}
    os.environ["PATH"] = f"{Path.home() / '.local/bin'}:{os.environ.get('PATH', '')}"
    batches = [tickets_list[i:i + BATCH] for i in range(0, len(tickets_list), BATCH)]
    with ThreadPoolExecutor(max_workers=6) as pool:
        rows = [r for rs in pool.map(classify, batches) for r in rs]
    dups = duplicates(rows, tickets)
    rows.sort(key=lambda r: -r.get("severity", -1))
    report = {"tickets": len(rows), "critical": [r["id"] for r in rows if r.get("severity", 0) >= 2.5],
              "needs_repro": [r["id"] for r in rows if r.get("needs_repro")], "duplicates": dups,
              "by_area": {a: sum(1 for r in rows if r.get("area") == a) for a in AREAS}, "rows": rows}
    if "--json" in sys.argv:
        print(json.dumps(report, indent=1)); return 0
    print(f"{len(rows)} tickets · {len(report['critical'])} critical · {len(report['needs_repro'])} need repro steps · {len(dups)} duplicate pairs\n")
    for r in rows:
        flag = " NEEDS-REPRO" if r.get("needs_repro") else ""
        print(f"sev={r.get('severity', '-')!s:4} {str(r.get('area', '-')):15} bug={r.get('is_bug', '-')!s:4} [{r['id']}] {r['title'][:60]}{flag}")
    for d in dups:
        print(f"DUP p={d['p']} [{d['a']}] ~ [{d['b']}]  ({d['area']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
