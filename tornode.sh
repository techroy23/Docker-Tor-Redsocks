#!/bin/sh
set -e

URL="https://raw.githubusercontent.com/maycon/tor-nodes-list/refs/heads/main/exit-nodes.json"
TOP_N="${1:-10}"

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

parse() {
    sort | uniq -c | sort -rn | head -n "$TOP_N" | awk '{printf "%s%s", (NR>1?",":""), $2} END {print ""}'
}

fetch_curl() {
    curl -sL -A "$UA" "$URL" 2>/dev/null | tr ',' '\n' | grep '"country"' | cut -d'"' -f4 | parse
}

fetch_wget() {
    wget -qO- --user-agent="$UA" "$URL" 2>/dev/null | tr ',' '\n' | grep '"country"' | cut -d'"' -f4 | parse
}

main() {
    fetch_curl && return 0
    fetch_wget && return 0
    return 1
}

main