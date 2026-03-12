#!/bin/bash
# xojo.sh – Xojo IDE Controller
# 
# Usage:
#   ./xojo.sh open /path/to/project.xojo_project
#   ./xojo.sh analyze [/path/to/project.xojo_project]
#   ./xojo.sh run [/path/to/project.xojo_project]
#   ./xojo.sh errors       # save clipboard → /tmp/xojo_errors.txt & display

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPLESCRIPT="$SCRIPT_DIR/xojo_controller.applescript"
ERROR_FILE="/tmp/xojo_errors.txt"

if [ $# -eq 0 ]; then
    echo "Xojo IDE Controller"
    echo "==================="
    echo ""
    echo "Commands:"
    echo "  open <path>        Open a .xojo_project file"
    echo "  analyze [<path>]   Analyze project (opens if path given)"
    echo "  run [<path>]       Run project (opens if path given)"
    echo "  errors             Save clipboard to $ERROR_FILE and display"
    echo ""
    echo "Workflow:"
    echo "  1. ./xojo.sh analyze ../path/to/project.xojo_project"
    echo "  2. In Xojo: right-click Issues panel → Copy All"
    echo "  3. ./xojo.sh errors"
    echo "  4. Paste errors to Claude:  cat $ERROR_FILE | pbcopy"
    exit 0
fi

COMMAND="$1"
shift

case "$COMMAND" in
    open|analyze|run)
        osascript "$APPLESCRIPT" "$COMMAND" "$@" 2>&1
        ;;
    errors)
        # Always clear the file first
        > "$ERROR_FILE"
        
        # Read clipboard
        CLIP="$(pbpaste 2>/dev/null)"
        
        if [ -z "$CLIP" ]; then
            echo "No errors. Project is clean."
        else
            echo "$CLIP" > "$ERROR_FILE"
            LINE_COUNT=$(echo "$CLIP" | wc -l | tr -d ' ')
            echo "=== Xojo Errors ($LINE_COUNT lines) ==="
            echo "$CLIP"
            echo ""
            echo "Saved to: $ERROR_FILE"
        fi
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Run without arguments for help."
        exit 1
        ;;
esac