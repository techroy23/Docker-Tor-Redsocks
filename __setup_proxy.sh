#!/bin/bash
set -e

TOP_N="${TOP_N:-10}"

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

func_net_admin() {
    if ! iptables -L >/dev/null 2>&1; then
        log "[ERROR] iptables not usable. Missing NET_ADMIN/NET_RAW or root privileges."
        log "[INFO] Run container with: --cap-add=NET_ADMIN --cap-add=NET_RAW --sysctl net.ipv4.ip_forward=1"
        exit 1
    fi
}

func_start_tor() {
    log "[INFO] Starting Tor as toruser..."
    pkill -f tor || true

    COUNTRIES=$(/app/tornode.sh "$TOP_N") || COUNTRIES=""
    log "[INFO] Using exit nodes: ${COUNTRIES:-default}"

    SHOW_TOR_LOGS="$(echo "${SHOW_TOR_LOGS:-false}" | tr '[:upper:]' '[:lower:]')"

    {
        echo "SocksPort 60000"
        if [ -n "$COUNTRIES" ]; then
            echo "ExitNodes $COUNTRIES"
            echo "StrictNodes 1"
        fi
        echo "DataDirectory /var/lib/tor"
    } > /etc/tor/torrc
    chown toruser:toruser /etc/tor/torrc

    cat /etc/tor/torrc

    if [ "$SHOW_TOR_LOGS" = "true" ]; then
        gosu toruser tor -f /etc/tor/torrc &
    else
        gosu toruser tor -f /etc/tor/torrc >/dev/null 2>&1 &
    fi
    tor_pid=$!
}

func_check_tor() {
    while true; do
        sleep 10
        checker=$(printf "%s\n" $CHECKERS | shuf -n1)
        resp=$(curl -L --max-redirs 10 --socks5 localhost:60000 -s --max-time 30 "https://$checker" || true)
        if [ -n "$resp" ]; then
            log "[INFO] TOR proxy is working: $resp (via $checker)"
            return 0
        else
            log "[WARN] TOR proxy not ready, retrying..."
        fi
    done
}

setup_redsocks() {
    cat > /etc/redsocks.conf <<EOF
base {
    log_debug = off;
    log_info = on;
    log = "stderr";
    daemon = off;
    redirector = iptables;
}
redsocks {
    local_ip = 127.0.0.1;
    local_port = 50000;
    ip = 127.0.0.1;
    port = 60000;
    type = socks5;
}
EOF
    log "[INFO] Redsocks config written"
}

setup_iptables() {
    iptables -t nat -F
    iptables -t nat -A OUTPUT -m owner --uid-owner toruser -j RETURN
    iptables -t nat -A OUTPUT -p tcp -d 127.0.0.1 -j RETURN
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j RETURN
    iptables -t nat -A OUTPUT -p tcp --dport 50000 -j RETURN
    iptables -t nat -A OUTPUT -p tcp --dport 60000 -j RETURN
    iptables -t nat -A OUTPUT -p udp -d 127.0.0.1 -j RETURN
    iptables -t nat -A OUTPUT -p udp --dport 53 -j RETURN
    iptables -t nat -A OUTPUT -p udp --dport 50000 -j RETURN
    iptables -t nat -A OUTPUT -p udp --dport 60000 -j RETURN
    iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports 50000
    log "[INFO] iptables rules applied"
}

func_set_proxy() {
    log "[INFO] Initializing proxy stack..."
    func_start_tor
    func_check_tor
    setup_redsocks
    setup_iptables
    redsocks -c /etc/redsocks.conf &
    redsocks_pid=$!
    sleep 5
    checker=$(printf "%s\n" $CHECKERS | shuf -n1)
    resp=$(curl -L --max-redirs 10 -s --max-time 30 "https://$checker" || true)
    if [ -n "$resp" ]; then
        log "[INFO] Global proxy via redsocks is working: $resp (via $checker)"
        touch /tmp/redsocks.ready
        return 0
    else
        log "[ERROR] Global proxy test failed"
        return 1
    fi
}

func_global_monitor() {
    while true; do
        log "[INFO] Cleaning up Tor and Redsocks..."
        pkill -f tor || true
        pkill -f redsocks || true
        rm -f /tmp/redsocks.ready || true
        func_set_proxy || { sleep 60; continue; }
        proxy_fail_count=0
        while true; do
            sleep 180
            checker=$(printf "%s\n" $CHECKERS | shuf -n1)
            resp=$(curl -L --max-redirs 10 -s --max-time 30 "https://$checker" || true)
            if [ -n "$resp" ]; then
                log "[GOOD] Global monitor check OK: $resp (via $checker)"
                proxy_fail_count=0
            else
                proxy_fail_count=$((proxy_fail_count+1))
                log "[ERROR] Proxy failure detected (consecutive fails: $proxy_fail_count)"
            fi
            if [ $proxy_fail_count -ge 3 ]; then
                log "[CRITICAL] Proxy failed 3 times in a row, restarting full stack..."
                break
            fi
        done
    done
}

CHECKERS="ifconfig.icu/ip
ifconfig.me/ip
ipecho.net/ip
ipinfo.io/ip
ipapi.co/ip
ip.im
eth0.me
ip.tyk.nu
a.ident.me
ip-addr.es
icanhazip.com
api64.ipify.org
wtfismyip.com/text
moanmyip.com/simple
checkip.amazonaws.com
whatismyip.akamai.com
jsonip.com
httpbin.org/ip"

func_net_admin
func_global_monitor