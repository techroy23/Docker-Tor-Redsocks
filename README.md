# Docker-Tor-Redsocks
A Docker base image that sets up a transparent proxy stack using Tor and Redsocks with iptables redirection. Import it into your Dockerfile to run any application behind a Tor-anonymized network.

## Features
- Alpine and Ubuntu variants (`Dockerfile.alpine`, `Dockerfile.ubuntu`)
- Dynamic exit node selection - fetches top 10 countries from live Tor network data
- Failsafe: uses default Tor exits if tornode.sh fails
- Redsocks for transparent TCP proxying
- iptables rules redirect all outbound traffic through Tor
- Automatic monitoring and restart on failure
- Readiness indicator: `/tmp/redsocks.ready`

## Files
| File | Description |
|:-----|:----------|
| `tornode.sh` | Fetches top N countries from Tor exit nodes |
| `__setup_proxy.sh` | Proxy setup and monitoring script |
| `Dockerfile.alpine` | Lightweight Alpine-based image |
| `Dockerfile.ubuntu` | Ubuntu-based image |

## Usage
### 1. Import into your Dockerfile
```dockerfile
# FROM ghcr.io/techroy23/docker-tor-redsocks:alpine
# or
# FROM ghcr.io/techroy23/docker-tor-redsocks:ubuntu

COPY . /app
RUN chmod +x /app/*.sh

ENTRYPOINT ["/app/your_program.sh"]
```

### 2. Run with required capabilities
```bash
docker run -it --rm \
  --sysctl net.ipv4.ip_forward=1 \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  yourimage:latest
```

### 3. In your entrypoint script
```bash
#!/bin/bash
set -e

/app/__setup_proxy.sh &

while [ ! -f /tmp/redsocks.ready ]; do
    sleep 5
done

echo "Proxy ready!"
./your_program
```

## Environment Variables
| Variable | Default | Description |
|:---------|:--------|:----------|
| `TOP_N` | 10 | Number of countries to use |
| `SHOW_TOR_LOGS` | false | Show Tor logs (true/false) |

## Examples
```bash
# Use top 3 countries
docker run -e TOP_N=3 yourimage

# Show Tor logs
docker run -e SHOW_TOR_LOGS=true yourimage

# Both
docker run -e TOP_N=3 -e SHOW_TOR_LOGS=true yourimage
```

## Notes
- Requires `NET_ADMIN` and `NET_RAW` capabilities
- Tor runs as dedicated `toruser`
- If tornode.sh fails, Tor uses its default global exit nodes