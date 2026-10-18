#!/usr/bin/env python3
"""UI source gate for the JJ frontend standard.

Scans TS/TSX/JS/JSX/CSS sources for the violations prose rules never stop on their own:
native controls, transition-all, literal durations, em dashes in copy, raw hex colours,
role-name checks, conditionally mounted overlays, broken Tailwind v4 token syntax, global
z literals, arbitrary scroll boxes, click-to-navigate rows, DOM reads for overlay state,
vendor names, duplicate components and repeated class lists.

Usage:
  python3 ui_check.py [PATH ...] [options]

Options:
  --exclude GLOB        skip matching paths (repeatable; node_modules, build output and tests are skipped already)
  --include-tests       also scan *.test.*, *.spec.*, __tests__/, tests/, e2e/
  --primitives GLOB     where the shared primitives live: raw native controls are allowed there (repeatable)
  --allow-hex GLOB      files allowed to hold raw hex colours, e.g. a token or chart palette module (repeatable)
  --vendor NAME         a vendor or internal system name that must never reach user-facing code (repeatable)
  --rule ID             run only these rules (repeatable)
  --skip-rule ID        skip these rules (repeatable)
  --strict              warnings fail too
  --json                print findings as JSON
  --list-rules          print the rules and exit

Suppress one line with a comment containing `ui-check-ignore` on that line or
`ui-check-ignore-next-line` on the line above; a whole file with `ui-check-ignore-file`.
Exit status: 0 clean, 1 findings at failing level, 2 usage error.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import sys
from dataclasses import dataclass, field

EXTS = {".ts", ".tsx", ".js", ".jsx", ".css", ".mjs", ".cjs"}
MARKUP = {".tsx", ".jsx"}
SKIP_DIRS = {"node_modules", ".next", "dist", "build", "out", "coverage", ".git", ".turbo", ".vercel", ".cache", "storybook-static"}
TEST_PATTERNS = ["*.test.*", "*.spec.*", "*/__tests__/*", "*/tests/*", "*/test/*", "*/e2e/*", "*/__mocks__/*"]
# Next.js / Remix route files legitimately share basenames across folders.
ROUTE_FILES = {"page", "layout", "loading", "error", "not-found", "template", "default", "route", "index", "global-error", "opengraph-image", "icon", "screen", "client"}

REPEAT_MIN_CHARS = 48
REPEAT_MIN_FILES = 3


@dataclass
class Rule:
    id: str
    level: str  # "error" | "warn"
    why: str
    pattern: re.Pattern | None = None
    exts: set[str] = field(default_factory=lambda: set(EXTS))
    code_only: bool = True  # strip comments before matching


RULES: list[Rule] = [
    Rule("native-control", "error",
         "Native controls draw OS chrome and snap open and shut. Use the house select, combobox, date/time picker, "
         "suggest input, confirm dialog or colour picker (a styled range input is fine).",
         re.compile(r"<(select|datalist)\b|type=[\"'](date|time|datetime-local|month|week|color)[\"']|\bwindow\.(confirm|alert|prompt)\(|(?<![\w.])(confirm|alert)\(\s*[\"'`]"),
         MARKUP | {".ts", ".js"}),
    Rule("details-element", "warn",
         "<details> snaps open and shut. Inside a modal, drawer or wizard use the animated Disclosure/Collapse primitive.",
         re.compile(r"<details\b"), MARKUP),
    Rule("transition-all", "error",
         "Name the transitioned properties (transition-[opacity,transform]) instead of transition-all.",
         re.compile(r"\btransition-all\b|transition:\s*all\b")),
    Rule("literal-duration", "warn",
         "Durations come from the motion tokens (control 160, surface 220, panel 280, collapse 240 ms): duration-(--motion-surface), not a literal.",
         re.compile(r"(?<![\w-])duration-(\d{2,4})(?![\w-])|(?<![\w-])duration-\[\d+m?s\]")),
    Rule("em-dash", "error",
         "No em dashes in UI copy. Rewrite with a full stop, a comma or a colon. A lone dash as the empty-value placeholder is fine.",
         re.compile(r"\w[ \t]*(?:—|&mdash;|&#8212;)|(?:—|&mdash;|&#8212;)[ \t]*\w"), MARKUP | {".ts", ".js"}),
    Rule("hex-colour", "warn",
         "Colours come from tokens. Move the value into the design-token layer (or allow the token file with --allow-hex).",
         re.compile(r"(?<![\w&/])#(?![0-9]+\b)(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b(?![\w-])"),
         MARKUP | {".ts", ".js"}),
    Rule("role-literal", "error",
         "Gate by a permission key (useCan('intro.request')), never by a role name. Roles are editable bundles of permissions.",
         re.compile(r"\brole(?:Id|Name|Key)?\s*[!=]==?\s*[\"'](?:admin|owner|manager|member|staff|editor|viewer|moderator|operator|super_?admin)[\"']"
                    r"|[\"'](?:admin|owner|manager|member|staff|editor|viewer|moderator|operator|super_?admin)[\"']\s*[!=]==?\s*[\w.]*role\b", re.I),
         MARKUP | {".ts", ".js"}),
    Rule("role-compare", "warn",
         "A decision by role name. If it gates what a person can do, test a permission key; if the value is display data, ignore the line.",
         re.compile(r"\brole(?:Id|Name|Key)?\s*[!=]==?\s*[\"'](?!(?:user|assistant|system|tool|function|developer|model|bot|ai"
                    r"|admin|owner|manager|member|staff|editor|viewer|moderator|operator|super_?admin)[\"'])[\w-]+[\"']", re.I),
         MARKUP | {".ts", ".js"}),
    Rule("conditional-overlay", "error",
         "Keep overlay owners mounted and drive them with open=..., or wrap them in the house Presence. A bare conditional mount cannot play its exit.",
         re.compile(r"\{\s*!?[\w.?()\[\]!]+\s*&&\s*\(?\s*<(Dialog|AlertDialog|Sheet|Drawer|Popover|DropdownMenu|ContextMenu|Modal|SimpleModal|Tooltip|HoverCard|Menu|Lightbox|FloatingWindow|BottomSheet|CommandDialog)\b"),
         MARKUP),
    Rule("tw4-bare-var", "warn",
         "In Tailwind v4 a token in a utility is bg-(--x) or bg-[var(--x)]. The v3 form bg-[--x] compiles to invalid CSS the browser drops silently.",
         re.compile(r"(?<![\w-])[a-z][\w-]*-\[--[\w-]+\]")),
    Rule("z-literal", "warn",
         "Global stacking comes from one layer scale (z-(--layer-overlay)). A literal z at overlay height drifts from the scale.",
         re.compile(r"(?<![\w-])z-\[\d{3,}\]|(?<![\w-])z-(?:50|\d{3,})(?![\w-])|z-index:\s*\d{3,}")),
    Rule("viewport-padding", "warn",
         "Viewport-relative padding hardcodes a layout. Use flex/grid distribution or a token.",
         re.compile(r"(?<![\w-])[pm][tblrxy]?-\[\d+(?:d|s|l)?v[hw]\]")),
    Rule("max-h-literal", "warn",
         "An arbitrary max-h scroll box is wrong for someone's screen. Fill the space (flex-1 min-h-0) or split it with a resizable pane.",
         re.compile(r"(?<![\w-])max-h-\[\d+px\]")),
    Rule("onclick-navigate", "warn",
         "Anything a person opens is a real <a href> (cmd-click, middle-click, open in new tab). Use a Link or a stretched row link.",
         re.compile(r"onClick=\{\s*\(\)\s*=>\s*(?:router\.(?:push|replace)|navigate)\("), MARKUP),
    Rule("overlay-dom-guard", "warn",
         "Ask the overlay layer store whether an overlay is open; never query the DOM for [role=dialog] or data-state=open.",
         re.compile(r"querySelector(?:All)?\([^)]*(?:role=[\"']?(?:dialog|menu)|data-state=[\"']?open)")),
    Rule("inline-style-literal", "warn",
         "Inline styles carry CSS-variable values only ({'--bar': value}); geometry and colour go through classes that read the variable.",
         re.compile(r"style=\{\{[^}]*(?:\b\d+px\b|#[0-9a-fA-F]{3,8}\b|rgba?\()"), MARKUP),
    Rule("vendor-name", "error",
         "No vendor or internal system names in user-facing code. The product is white-labeled.", None, MARKUP),
    Rule("duplicate-component", "warn",
         "Two components share a basename. Keep one owner (hoist it to the shared layer) and import it; never build a sibling.", None, MARKUP),
    Rule("repeated-class", "warn",
         f"The same class list (>= {REPEAT_MIN_CHARS} chars) appears in {REPEAT_MIN_FILES}+ files. Extract a component or a variant.", None, MARKUP),
]
RULE_BY_ID = {r.id: r for r in RULES}

BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
LINE_COMMENT = re.compile(r"(?<![:\"'`\\])//.*$")
IMPORT_LINE = re.compile(r"^\s*(import|export\s+\*|export\s+\{[^}]*\}\s+from)\b")
LAYOUT_TOKEN = re.compile(
    r"^(flex|grid|inline-flex|block|inline|hidden|contents|relative|absolute|fixed|sticky|shrink-0|shrink|grow|flex-1|flex-none|"
    r"flex-col|flex-row|flex-wrap|min-h-0|min-w-0|h-full|w-full|size-full|inset-0|items-\w+|justify-\w+|gap(-[xy])?-[\d.]+|"
    r"overflow-\w+|overflow-[xy]-\w+|truncate|text-(left|right|center)|m[lrxy]?-auto|self-\w+)$")
CLASS_TOKEN = re.compile(r"^!?[a-z][\w\-\[\]():/.%,&>*='!#]*$")
CLASS_STRING = re.compile(r"[\"'`]([^\"'`\n]{%d,})[\"'`]" % REPEAT_MIN_CHARS)


@dataclass
class Finding:
    rule: str
    level: str
    file: str
    line: int
    text: str


def strip_comments(source: str) -> str:
    """Blank out comments but keep line numbers."""
    def blank(m: re.Match) -> str:
        return re.sub(r"[^\n]", " ", m.group(0))
    out = BLOCK_COMMENT.sub(blank, source)
    return "\n".join(LINE_COMMENT.sub("", ln) for ln in out.split("\n"))


def matches(path: str, globs: list[str]) -> bool:
    p = path.replace(os.sep, "/")
    return any(fnmatch.fnmatch(p, g) or fnmatch.fnmatch("/" + p, g) or fnmatch.fnmatch(p, "*/" + g.lstrip("*/")) for g in globs)


def walk(paths: list[str], excludes: list[str], include_tests: bool) -> list[str]:
    files: list[str] = []
    for root in paths:
        if os.path.isfile(root):
            files.append(root)
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS and not d.startswith("."))
            for name in sorted(filenames):
                full = os.path.join(dirpath, name)
                ext = os.path.splitext(name)[1]
                if ext not in EXTS or name.endswith(".d.ts") or ".min." in name:
                    continue
                if matches(full, excludes):
                    continue
                if not include_tests and matches(full, TEST_PATTERNS):
                    continue
                files.append(full)
    return files


def vendor_pattern(names: list[str]) -> re.Pattern | None:
    names = [n.strip() for n in names if n.strip()]
    if not names:
        return None
    return re.compile(r"(?<![\w-])(" + "|".join(re.escape(n) for n in names) + r")(?![\w-])", re.I)


def check(args: argparse.Namespace) -> list[Finding]:
    active = {r.id for r in RULES}
    if args.rule:
        active &= set(args.rule)
    active -= set(args.skip_rule or [])
    vendor_re = vendor_pattern(args.vendor or [])
    files = walk(args.paths, args.exclude or [], args.include_tests)
    findings: list[Finding] = []
    class_index: dict[str, set[str]] = {}
    basenames: dict[str, list[str]] = {}

    for path in files:
        try:
            source = open(path, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        if "ui-check-ignore-file" in source:
            continue
        rel = os.path.relpath(path)
        ext = os.path.splitext(path)[1]
        raw_lines = source.split("\n")
        code_lines = strip_comments(source).split("\n")

        def ignored(i: int) -> bool:
            return "ui-check-ignore" in raw_lines[i] and "ui-check-ignore-next-line" not in raw_lines[i] or (
                i > 0 and "ui-check-ignore-next-line" in raw_lines[i - 1])

        for rule in RULES:
            if rule.id not in active or ext not in rule.exts:
                continue
            pattern = vendor_re if rule.id == "vendor-name" else rule.pattern
            if pattern is None:
                continue
            if rule.id == "native-control" and matches(path, args.primitives or []):
                continue
            if rule.id == "hex-colour" and matches(path, args.allow_hex or []):
                continue
            lines = code_lines if rule.code_only else raw_lines
            for i, text in enumerate(lines):
                if not text.strip() or ignored(i):
                    continue
                if rule.id == "vendor-name" and IMPORT_LINE.match(text):
                    continue
                if pattern.search(text):
                    findings.append(Finding(rule.id, rule.level, rel, i + 1, raw_lines[i].strip()[:140]))

        if ext in MARKUP:
            stripped = "\n".join(code_lines)
            for m in CLASS_STRING.finditer(stripped):
                text = m.group(1).strip()
                tokens = text.split()
                if len(tokens) < 3 or not all(CLASS_TOKEN.match(t) for t in tokens) or all(LAYOUT_TOKEN.match(t) for t in tokens):
                    continue
                class_index.setdefault(text, set()).add(rel)
            stem = os.path.splitext(os.path.basename(path))[0]
            if stem not in ROUTE_FILES and not stem.startswith("_") and re.match(r"^[A-Za-z][\w-]*$", stem):
                basenames.setdefault(stem.lower(), []).append(rel)

    if "repeated-class" in active:
        for text, where in class_index.items():
            if len(where) >= REPEAT_MIN_FILES:
                findings.append(Finding("repeated-class", RULE_BY_ID["repeated-class"].level, ", ".join(sorted(where)), 0, text[:140]))
    if "duplicate-component" in active:
        for stem, where in basenames.items():
            dirs = {os.path.dirname(w) for w in where}
            if len(where) > 1 and len(dirs) > 1:
                findings.append(Finding("duplicate-component", RULE_BY_ID["duplicate-component"].level, ", ".join(sorted(where)), 0, stem))
    return findings


def print_report(findings: list[Finding], file_count: int) -> None:
    by_rule: dict[str, list[Finding]] = {}
    for f in findings:
        by_rule.setdefault(f.rule, []).append(f)
    order = sorted(by_rule, key=lambda r: (RULE_BY_ID[r].level != "error", r))
    for rid in order:
        group = by_rule[rid]
        rule = RULE_BY_ID[rid]
        print(f"\n{rid} [{rule.level}] ({len(group)}): {rule.why}")
        for f in group[:40]:
            if f.line:
                print(f"  {f.file}:{f.line}  {f.text}")
            else:
                print(f"  {f.text}\n    " + "\n    ".join(f.file.split(", ")))
        if len(group) > 40:
            print(f"  ... {len(group) - 40} more")
    errors = sum(1 for f in findings if f.level == "error")
    warns = len(findings) - errors
    print(f"\nui-check: {errors} error(s), {warns} warning(s) across {file_count} files")


def main() -> int:
    ap = argparse.ArgumentParser(description="UI source gate for the JJ frontend standard.")
    ap.add_argument("paths", nargs="*", default=["src"])
    ap.add_argument("--exclude", action="append")
    ap.add_argument("--include-tests", action="store_true")
    ap.add_argument("--primitives", action="append")
    ap.add_argument("--allow-hex", action="append")
    ap.add_argument("--vendor", action="append")
    ap.add_argument("--rule", action="append")
    ap.add_argument("--skip-rule", action="append")
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--list-rules", action="store_true")
    args = ap.parse_args()

    if args.list_rules:
        for r in RULES:
            print(f"{r.id:22} {r.level:5}  {r.why}")
        return 0
    unknown = [r for r in (args.rule or []) + (args.skip_rule or []) if r not in RULE_BY_ID]
    if unknown:
        print(f"ui-check: unknown rule(s): {', '.join(unknown)} (see --list-rules)", file=sys.stderr)
        return 2
    missing = [p for p in args.paths if not os.path.exists(p)]
    if missing:
        print(f"ui-check: path not found: {', '.join(missing)}", file=sys.stderr)
        return 2

    file_count = len(walk(args.paths, args.exclude or [], args.include_tests))
    findings = check(args)
    if args.json:
        print(json.dumps([f.__dict__ for f in findings], indent=2))
    else:
        print_report(findings, file_count)
    failing = [f for f in findings if f.level == "error" or args.strict]
    return 1 if failing else 0


if __name__ == "__main__":
    sys.exit(main())
