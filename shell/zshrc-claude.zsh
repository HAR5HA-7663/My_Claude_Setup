# Append to ~/.zshrc (or the equivalent for your shell).
# `claude` launches with function hooks on so the jev-compact plugin can take over compaction;
# the plugin reads TYPESAFE_API_KEY from ~/.env itself — nothing is exported into the process env.
claude() {
  CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1 command claude "$@"
}
alias claude-plain='command claude'                       # without function hooks
alias lawde='claude --dangerously-skip-permissions'       # when you really mean it
