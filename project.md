# Docker-Tor-Redsocks

## Description
Docker base image with transparent Tor proxy stack using Redsocks and iptables.

## Tech Stack
- Docker (Alpine / Ubuntu)
- Tor
- Redsocks
- iptables
- Bash

## Current Status
- Working: Tor transparent proxy via iptables redirection
- Working: Dual Alpine/Ubuntu image variants
- Working: SOCKS5 exposure on port 40001
- Working: Health monitoring and auto-restart on failure
- Working: CI/CD via GHCR with GitHub Actions
- Removed: Dynamic exit node selection (tornode.sh) — now uses default Tor exits

## Goals
- [ ] Add `.dockerignore` to slim build context
- [ ] Add signal handling for graceful shutdown
- [ ] Fix UDP/DNS leak — ensure all non-loopback traffic goes through Tor
- [ ] Add ARM64 multi-arch builds
- [ ] Add test suite for proxy verification

## Recent Changes
- Removed `tornode.sh` — dynamic exit node selection removed in favor of Tor defaults
- Simplified `__setup_proxy.sh` — no longer fetches exit node countries
- Updated docs to remove `TOP_N` and exit node configuration
