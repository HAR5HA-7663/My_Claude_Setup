#!/usr/bin/env python3
"""jev-triage-messages.py — Jev filter for a pile of Slack messages / SMS before an LLM reads them.

    python3 jev-triage-messages.py messages.json [--json] [--me "Harsha"]

messages.json: list of {"id", "source": "slack"|"sms", "channel", "from", "ts", "text",
                        "thread"?: "<parent text>"}
Output (table, or --json): every message with
    needs_reply      noul   someone is waiting on Harsha specifically
    urgency          score  0 none · 1 this week · 2 today · 3 now
    kind             choice question_for_me | request_for_me | fyi | decision_needed | social | automated | spam
    sensitive        noul   bank / immigration / other people's private detail
    verdict          REPLY-NOW | REPLY-TODAY | READ | IGNORE

Only the flagged ones (REPLY-NOW / REPLY-TODAY / decision_needed) should go on to Claude for
drafting. Batched 12 messages per Jev request; ~$0.00005 per message. Never sends anything.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

BATCH = 12
KINDS = {
    "question_for_me": "a question addressed to Harsha that only he can answer",
    "request_for_me": "asks Harsha to do, check, approve, send or fix something",
    "decision_needed": "a decision, approval or go/no-go is being waited on from Harsha",
    "fyi": "information, status or an announcement; no action expected from Harsha",
    "social": "greetings, thanks, banter, reactions",
    "automated": "a bot, alert, calendar, CI or system notification",
    "spam": "promotional, irrelevant or unsolicited",
}


def questions_for(n: int, me: str) -> dict:
    qs = {}
    for i in range(1, n + 1):
        qs[f"m{i}_needs_reply"] = {"type": "noul", "instructions": f"Is someone waiting for a reply or action from {me} specifically on MESSAGE {i}? A message addressed to the whole group with no ask, or already answered in the THREAD, does not count."}
        qs[f"m{i}_urgency"] = {"type": "score", "instructions": f"How time-sensitive is MESSAGE {i} for {me}?", "criteria": [
            "No time pressure or nothing for him to do", "Sometime this week", "Today", "Right now: an outage, a blocked colleague, a deadline within hours"]}
        qs[f"m{i}_kind"] = {"type": "choice", "instructions": f"What is MESSAGE {i}?", "criteria": KINDS}
        qs[f"m{i}_sensitive"] = {"type": "noul", "instructions": f"Does MESSAGE {i} contain bank, card or loan details, immigration case details, or private information about a person other than {me}?"}
    return qs


def state_for(batch: list[dict], me: str) -> str:
    parts = [f"{me} is a CRM & integration engineer. These are recent Slack messages and text messages he received. "
             "Judge each MESSAGE on its own; THREAD is earlier context when present."]
    for i, m in enumerate(batch, 1):
        head = f"MESSAGE {i} [{m.get('source', '?')} · {m.get('channel', '')} · from {m.get('from', '?')} · {m.get('ts', '')}]"
        thread = f"\nTHREAD: {str(m['thread'])[:400]}" if m.get("thread") else ""
        parts.append(f"{head}{thread}\nTEXT: {str(m.get('text', ''))[:1200]}")
    return "\n\n".join(parts)


def triage(batch: list[dict], me: str) -> list[dict]:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as q:
        json.dump(questions_for(len(batch), me), q)
        qpath = q.name
    try:
        r = subprocess.run(["jev-ask", "--purpose", "msg-triage", "--deadline", "5000", "--questions-file", qpath],
                           input=state_for(batch, me), capture_output=True, text=True, timeout=7)
        a = json.loads(r.stdout) if r.returncode == 0 else {}
    except Exception:  # noqa: BLE001
        a = {}
    finally:
        os.unlink(qpath)
    out = []
    for i, m in enumerate(batch, 1):
        row = {k: m.get(k) for k in ("id", "source", "channel", "from", "ts")}
        row["text"] = str(m.get("text", ""))[:160]
        try:
            nr = float(a[f"m{i}_needs_reply"]["noul"]); ur = float(a[f"m{i}_urgency"]["score"])
            kind = a[f"m{i}_kind"]["choice"]; sens = float(a[f"m{i}_sensitive"]["noul"])
        except (KeyError, TypeError, ValueError):
            row.update(verdict="UNSCORED"); out.append(row); continue
        row.update(needs_reply=round(nr, 2), urgency=round(ur, 2), kind=kind, sensitive=round(sens, 2))
        if kind in ("automated", "spam") or (nr < 0.3 and kind in ("fyi", "social")):
            row["verdict"] = "IGNORE" if kind in ("spam",) else "READ"
        elif (nr >= 0.5 or kind == "decision_needed") and ur >= 2.0:
            row["verdict"] = "REPLY-NOW"
        elif nr >= 0.5 or kind in ("decision_needed", "request_for_me", "question_for_me"):
            row["verdict"] = "REPLY-TODAY"
        else:
            row["verdict"] = "READ"
        out.append(row)
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__); return 2
    me = sys.argv[sys.argv.index("--me") + 1] if "--me" in sys.argv else "Harsha"
    msgs = json.loads(Path(sys.argv[1]).read_text())
    os.environ["PATH"] = f"{Path.home() / '.local/bin'}:{os.environ.get('PATH', '')}"
    batches = [msgs[i:i + BATCH] for i in range(0, len(msgs), BATCH)]
    with ThreadPoolExecutor(max_workers=6) as pool:
        rows = [r for rs in pool.map(lambda b: triage(b, me), batches) for r in rs]
    order = {"REPLY-NOW": 0, "REPLY-TODAY": 1, "UNSCORED": 2, "READ": 3, "IGNORE": 4}
    rows.sort(key=lambda r: (order[r["verdict"]], -r.get("urgency", 0)))
    if "--json" in sys.argv:
        print(json.dumps(rows, indent=1)); return 0
    counts = {k: sum(r["verdict"] == k for r in rows) for k in order}
    print(f"{len(rows)} messages: " + ", ".join(f"{v} {k}" for k, v in counts.items() if v) + "\n")
    for r in rows:
        if r["verdict"] in ("READ", "IGNORE"):
            continue
        print(f"{r['verdict']:11} urg={r.get('urgency', '-')!s:4} reply={r.get('needs_reply', '-')!s:4} {str(r.get('kind', '-')):16} "
              f"[{r.get('source', '?')}·{str(r.get('channel', ''))[:14]}] {str(r.get('from', ''))[:14]:14} {r['text'][:70]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
