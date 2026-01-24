# Docker-Tor-Redsocks
This project provides a Docker base image that automatically sets up a transparent proxy stack using Tor and Redsocks, with iptables redirection. It is designed to be imported into your own Dockerfile, so you can run your application behind a monitored global proxy.

## Features
- Alpine and Ubuntu variants (Dockerfile.alpine, Dockerfile.ubuntu).
- Preconfigured Tor with selected exit nodes (US, NL, DE, SE, PL, AT).
- Redsocks integration for transparent proxying.
- iptables rules to redirect all outbound traffic through the proxy.
- Automatic monitoring and restart of the proxy stack.
- Simple readiness check: a .ready file is created once the proxy is confirmed working.

## Files
| Filename | Description |
|:---------|:------------|
| Dockerfile.alpine | Lightweight Alpine‑based image |
| Dockerfile.ubuntu | Ubuntu‑based image |
| __setup_proxy.sh | Proxy setup and monitoring script |

## Usage
1. Import into your Dockerfile
- In your own project’s Dockerfile, use this image as the base:
  ```Dockerfile
  # FROM ghcr.io/techroy23/docker-tor-redsocks:alpine
  # or
  # FROM ghcr.io/techroy23/docker-tor-redsocks:ubuntu
  
  COPY . /app
  RUN chmod +x /app/your_program.sh
  
  ENTRYPOINT ["/app/your_program.sh"]
  ```
2. Run the container with required capabilities
- The proxy stack requires NET_ADMIN and NET_RAW capabilities.
  ```bash
  docker run -it --rm \
    --sysctl net.ipv4.ip_forward=1 \
    --cap-add=NET_ADMIN --cap-add=NET_RAW \
    yourimage:latest
  ```
3. Monitor readiness
- The proxy setup script will:
- Start Tor as toruser > Configure Redsocks > Apply iptables rules > Continuously monitor connectivity
- Once the proxy is confirmed working, a file /tmp/redsocks.ready will be created inside the container.
- You can check for readiness in your own program:
  ```bash
  #!/bin/bash
  set -e   # Exit immediately if any command fails (safety measure)
  
  ###############################################################################
  # STEP 1: Customize Tor exit nodes (optional)
  #
  # Tor chooses random exit nodes by default. If you want to force traffic
  # through specific countries, you can edit /etc/tor/torrc.
  #
  # Use ISO country codes inside curly braces, separated by commas.
  # Example below sets exit nodes to France (fr), Canada (ca), and Japan (jp).
  # Uncomment the sed line to apply this change automatically at container start.
  ###############################################################################
  
  # sed -i 's/^ExitNodes.*/ExitNodes {fr},{ca},{jp}/' /etc/tor/torrc
  
  ###############################################################################
  # STEP 2: Start the proxy stack
  #
  # __setup_proxy.sh is the script included in this base image that:
  #   - Starts Tor as the dedicated "toruser"
  #   - Configures Redsocks to redirect traffic through Tor
  #   - Applies iptables rules for transparent proxying
  #   - Monitors connectivity and restarts the stack if needed
  #
  # IMPORTANT: Run it in the background (&) so your own application can start.
  ###############################################################################
  
  /app/__setup_proxy.sh &
  
  ###############################################################################
  # STEP 3: Wait until proxy is ready
  #
  # The setup script will create a marker file (/tmp/redsocks.ready)
  # once Tor + Redsocks are confirmed working.
  #
  # This loop checks for that file every 5 seconds before continuing.
  ###############################################################################
  
  while [ ! -f /tmp/redsocks.ready ]; do
    echo "Waiting for proxy to be ready..."
    sleep 5
  done
  
  ###############################################################################
  # STEP 4: Launch your application
  #
  # At this point, all outbound TCP traffic from the container is transparently
  # redirected through Tor via Redsocks. Your program can run normally without
  # needing to be proxy-aware.
  ###############################################################################
  
  echo "Proxy is ready! Starting application..."
  ./your_program_here
  ```

## Customization
- Exit nodes: Adjust /etc/tor/torrc in your derived image to change countries.
- Monitoring targets: The script cycles through multiple IP checkers (e.g., ifconfig.me, ipinfo.io) to validate proxy health.

## Notes
- Ensure your container runs with the required capabilities; otherwise, iptables will fail.
- The proxy stack is designed for global redirection.
- Logs are timestamped and prefixed with >>> An2Kin >>> for clarity.
