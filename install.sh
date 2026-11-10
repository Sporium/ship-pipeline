#!/usr/bin/env bash
# Install the ship pipeline (skills `ship` + `debate` and 8 agents) for Claude Code and/or Codex.
#
#   ./install.sh /path/to/repo            project scope, both tools
#   ./install.sh --user                   personal scope (~), both tools
#   add --claude or --codex to install for one tool only
#   add --force to overwrite existing files
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
TARGET=""; CLAUDE=1; CODEX=1; FORCE=0
for a in "$@"; do
  case "$a" in
    --user) TARGET="$HOME" ;;
    --claude) CODEX=0 ;;
    --codex) CLAUDE=0 ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n 2,8p "$0"; exit 0 ;;
    *) TARGET="$a" ;;
  esac
done
[[ -n "$TARGET" && -d "$TARGET" ]] || { sed -n 2,8p "$0" >&2; exit 1; }

copy() { # src dest
  if [[ -e "$2" && $FORCE -eq 0 ]]; then echo "  skip (exists): $2"; return; fi
  rm -rf "$2"; mkdir -p "$(dirname "$2")"; cp -R "$1" "$2"; echo "  + $2"
}

if [[ $CLAUDE -eq 1 ]]; then
  echo "Claude Code:"
  for s in ship debate; do copy "$SRC/skills/$s" "$TARGET/.claude/skills/$s"; done
  for f in "$SRC"/agents/claude/*.md; do copy "$f" "$TARGET/.claude/agents/$(basename "$f")"; done
fi
if [[ $CODEX -eq 1 ]]; then
  echo "Codex:"
  for s in ship debate; do copy "$SRC/skills/$s" "$TARGET/.agents/skills/$s"; done
  for f in "$SRC"/agents/codex/*.toml; do copy "$f" "$TARGET/.codex/agents/$(basename "$f")"; done
fi
echo
echo "Done. Restart the tool, then:"
[[ $CLAUDE -eq 1 ]] && echo "  Claude Code:  /ship plan only <task>"
[[ $CODEX -eq 1 ]] && echo "  Codex:        \$ship plan only <task>   (and merge codex-config.example.toml into ~/.codex/config.toml)"
exit 0
