#!/usr/bin/env node
// pr-push listener — subscribes to the pr-push Worker (Cloudflare) and wakes the PR
// babysitter the moment GitHub reports a review, comment, CI result or merge on a
// PR it is tracking. Outbound connection only, so it works from any network.
//
// On an event for a tracked PR: touch ~/.claude/pr-babysitter/.poke-<owner>-<repo>-<pr>
// (a live in-chat watcher wakes from its wait and polls now) and run
// `pr-babysitter.sh sweep` (covers PRs whose watcher is gone). The 60 s launchd sweep
// stays as the fallback. Remembers the last event id and catches up after sleep /
// offline. Token: ~/.config/pr-push/sub_token. Log: ~/.claude/pr-babysitter/push.log
// Run by launchd com.harsha.pr-push-listen (KeepAlive).

import { readFileSync, writeFileSync, existsSync, appendFileSync, utimesSync, closeSync, openSync } from "node:fs";
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const HOME = homedir();
const URL_BASE = process.env.PR_PUSH_URL || "wss://pr-push.harsha7663.workers.dev/ws";
const DIR = join(HOME, ".claude/pr-babysitter");
const LAST = join(DIR, ".push-last-id");
const LOG = join(DIR, "push.log");
const BOTSH = join(HOME, ".claude/scripts/pr-babysitter.sh");
const ACTIVE = new Set(["waiting", "ci_pending", "changes_requested", "conflict", "ci_failed"]);
const TOKEN = readFileSync(join(HOME, ".config/pr-push/sub_token"), "utf8").trim();

const log = (m) => appendFileSync(LOG, `${new Date().toISOString().replace("T", " ").slice(0, 19)} ${m}\n`);
const lastId = () => { try { return parseInt(readFileSync(LAST, "utf8"), 10) || 0; } catch { return 0; } };

let sweepTimer = null, sweeping = false, sweepAgain = false;
function sweepSoon() {
  clearTimeout(sweepTimer);
  sweepTimer = setTimeout(runSweep, 2000);   // debounce bursts (review + comments arrive together)
}
function runSweep() {
  if (sweeping) { sweepAgain = true; return; }
  sweeping = true;
  const p = spawn("/bin/bash", [BOTSH, "sweep"], { stdio: "ignore", env: { ...process.env, PATH: `${process.env.PATH}:/opt/homebrew/bin:/usr/local/bin:${HOME}/.local/bin` } });
  p.on("exit", () => {
    sweeping = false;
    if (sweepAgain) { sweepAgain = false; sweepSoon(); }
  });
}

function handle(e) {
  if (e.hello) { log(`connected, hub at #${e.last}`); if (!lastId()) writeFileSync(LAST, String(e.last)); return; }
  if (!e.id) return;
  writeFileSync(LAST, String(e.id));
  if (!e.repo || !e.pr) return;
  const key = `${e.repo.replace("/", "-")}-${e.pr}`;
  const state = join(DIR, `${key}.json`);
  if (!existsSync(state)) return;
  let st = "", cwd = "";
  try { ({ status: st = "", cwd = "" } = JSON.parse(readFileSync(state, "utf8"))); } catch {}
  if (!ACTIVE.has(st)) return;
  // Ownership: the PR belongs to the device whose chat folder holds it. Both Macs get every
  // event; the other device must never act on it.
  if (cwd && !existsSync(cwd)) { log(`#${e.id} ${e.repo}#${e.pr} skipped — owned by another device (${cwd})`); return; }
  const poke = join(DIR, `.poke-${key}`);
  if (!existsSync(poke)) closeSync(openSync(poke, "w"));
  const now = new Date(); utimesSync(poke, now, now);
  log(`#${e.id} ${e.repo}#${e.pr} ${e.event} ${e.action} ${e.state} by ${e.sender} -> poked (${st})`);
  sweepSoon();
}

let backoff = 1000;
function connect() {
  const ws = new WebSocket(`${URL_BASE}?token=${encodeURIComponent(TOKEN)}&after=${lastId()}`);
  let alive = Date.now(), ping;
  ws.onopen = () => {
    backoff = 1000;
    ping = setInterval(() => {
      if (Date.now() - alive > 90000) { log("no traffic for 90s — reconnecting"); try { ws.close(); } catch {} return; }
      try { ws.send("ping"); } catch {}
    }, 30000);
  };
  ws.onmessage = (m) => {
    alive = Date.now();
    if (m.data === "pong") return;
    try { handle(JSON.parse(m.data)); } catch (err) { log(`bad message: ${err}`); }
  };
  const retry = () => {
    clearInterval(ping);
    setTimeout(connect, backoff);
    backoff = Math.min(backoff * 2, 60000);
  };
  ws.onclose = (ev) => { log(`disconnected (${ev.code}) — retry in ${backoff / 1000}s`); retry(); };
  ws.onerror = () => {};   // onclose follows
}

log("listener starting");
connect();
