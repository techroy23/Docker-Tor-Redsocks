#!/bin/sh
set -e

URL="https://raw.githubusercontent.com/maycon/tor-nodes-list/refs/heads/main/exit-nodes.json"
TOP_N="${1:-10}"

fetch() {
    curl -sL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "$URL" 2>/dev/null | \
        tr ',' '\n' | grep '"country"' | cut -d'"' -f4 | sort | uniq -c | sort -rn | head -n "$TOP_N" | \
        awk '{printf "%s%s", (NR>1?",":""), $2} END {print ""}'
}

fetch || wget -qO- --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "$URL" 2>/dev/null | \
    tr ',' '\n' | grep '"country"' | cut -d'"' -f4 | sort | uniq -c | sort -rn | head -n "$TOP_N" | \
    awk '{printf "%s%s", (NR>1?",":""), $2} END {print ""}'