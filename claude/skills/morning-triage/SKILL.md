---
name: morning-triage
description: Morning message triage. Pulls the last ~14 hours of Slack (channels + DMs) and SMS, lets Jev score every message for needs-reply / urgency / kind / sensitivity in one cheap pass, and drafts replies in Harsha's voice only for the ones that need him. Use when the user says "/morning-triage", "what do i need to reply to", "triage my messages", or when the 08:30 launchd job runs it headless. Never sends anything.
---

# morning-triage

Jev reads everything; Claude reads only what Jev flagged; Harsha reads a one-screen digest.

## Steps

1. **Window.** Default: since 18:00 yesterday (or since the last digest in
   `~/Desktop/morning-triage/`, whichever is later). The user can say "since Friday".

2. **Collect, read-only.**
   - Slack (MCP): do NOT read all ~125 channels one by one (the first headless run took
     26 min doing that). Instead `slack_search_public_and_private` with `after:<window
     start date>` (a few searches: `after:YYYY-MM-DD`, plus `to:me`/`@harsha` mentions
     and `is:dm`) to find which channels/DMs actually had traffic, then
     `slack_read_channel` only those. Include thread parents as `thread` text when a
     message is a reply; if a thread read fails once, retry once, then note it in the
     digest and move on. Cap 400 messages. Work inline — do not spawn subagents for
     collection (mem-guard refuses them under memory pressure and inline is fine).
   - SMS (gmessages MCP): `list_conversations` → `get_messages` for the window.
   Write them to `~/Desktop/morning-triage/.inbox-YYYY-MM-DD.json` as a list of
   `{"id","source":"slack"|"sms","channel","from","ts","text","thread"?}`.
   Only messages *to* Harsha or in his channels; drop his own messages.

3. **Score with Jev.**
   ```
   python3 ~/.claude/scripts/jev-triage-messages.py ~/Desktop/morning-triage/.inbox-YYYY-MM-DD.json --json
   ```
   Verdicts: `REPLY-NOW`, `REPLY-TODAY`, `READ`, `IGNORE`, `UNSCORED`. Treat `UNSCORED` as `READ`
   and skim it yourself.

4. **Draft replies** for `REPLY-NOW` and `REPLY-TODAY` only, in Harsha's Slack voice
   (`/Users/HAR5HA/brain/assets/harsha-slack-writing-style.md`: lowercase, casual, no
   bullets). For anything with `sensitive >= 0.5` (bank, immigration, someone else's private
   data) draft nothing beyond "will check and get back" and flag it. If a reply needs a fact
   you don't have, `/brain-query` it first; if still unknown, leave a `[?]` placeholder.

5. **Write the digest** to `~/Desktop/morning-triage/YYYY-MM-DD.md`:
   ```
   # morning triage — YYYY-MM-DD 08:30
   N messages · X reply now · Y reply today · Z read · rest ignored

   ## reply now
   - [slack #nexamortgage] Court, 08:41 — invoice shows $0 tax before 11am call
     draft: "..."
   ## reply today
   ...
   ## read (no reply needed)
   - one line each
   ```
   Then `osascript -e 'display notification "X reply-now, Y today" with title "morning triage"'`.

6. **Never send.** Drafts stay in the digest until Harsha pastes or says "send #2".

## Rules

- Read-only tools only. In the headless run the allowed-tools list excludes every
  send/post/react tool; in an interactive run, do not use them either.
- Message text goes to TypeSafe's API for scoring. Nothing else does.
- If Jev is unavailable the script exits non-zero: fall back to reading everything
  yourself and say so in the digest header.
