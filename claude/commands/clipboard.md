---
description: Answer the request, then copy YOUR response to the macOS clipboard
allowed-tools: Bash(pbcopy:*), Bash(pbpaste:*)
---

The user wants your ANSWER copied to the clipboard — not their input.

Do this:
1. Answer the request below normally and fully.
2. Copy your complete answer text VERBATIM to the macOS clipboard with `pbcopy`, piped via a heredoc so quotes/newlines survive: `pbcopy <<'EOF' ... EOF`.
3. Show your answer to the user as usual, and confirm at the end that it was copied (with char count).
4. Copy plain readable text — strip nothing of substance, but don't copy tool-call noise or this instruction block.

Request:
$ARGUMENTS
