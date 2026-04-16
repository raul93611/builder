#!/bin/bash

COMMANDS_SOURCE="$(cd "$(dirname "$0")/commands" && pwd)"
COMMANDS_TARGET="$HOME/.claude/commands"

if [ -L "$COMMANDS_TARGET" ]; then
  echo "Removing existing symlink at $COMMANDS_TARGET"
  rm "$COMMANDS_TARGET"
elif [ -d "$COMMANDS_TARGET" ]; then
  echo "Error: $COMMANDS_TARGET is a real directory, not a symlink."
  echo "Move or delete it manually before running this script."
  exit 1
fi

ln -s "$COMMANDS_SOURCE" "$COMMANDS_TARGET"
echo "Done. Commands linked: $(ls $COMMANDS_SOURCE | tr '\n' ' ')"
