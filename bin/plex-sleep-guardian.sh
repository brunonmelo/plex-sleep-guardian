#!/bin/bash
set -euo pipefail

TOKEN="7U1Hqjp6SKPNqC7ap6Wh"
URL="http://localhost:32400/status/sessions"
INHIBIT_PID_FILE=/run/plex_inhibit.pid
LOG_FILE=/tmp/plex‑inhibit.log

log_message() {
    echo "[$(date +"%Y.%m.%d-%T")] $1" >> "$LOG_FILE"
}

# ver se já há um lock ativo
has_lock() {
    systemd-inhibit --list --no-pager | grep -q 'Plex Inhibit'
}

# criar/retirar lock
start_inhibit() {
    # evita criar dois locks ao mesmo tempo
    [[ -f "$INHIBIT_PID_FILE" ]] && return
    systemd-inhibit --what=sleep --who="Plex Inhibit" --why="Plex is streaming" --mode=block sleep infinity &
    echo $! > "$INHIBIT_PID_FILE"
}

stop_inhibit() {
    [[ -f "$INHIBIT_PID_FILE" ]] && {
        kill "$(cat "$INHIBIT_PID_FILE")" &>/dev/null || true
        rm -f "$INHIBIT_PID_FILE"
    }
}

# checa o Plex
check_plex() {
    resp=$(curl -s -f \
        -H "X-Plex-Token: $TOKEN" \
        -H "Accept: application/json" \
        "$URL") || { log_message "❌  curl falhou"; exit 0; }

    size=$(echo "$resp" | jq -e -r '.MediaContainer.size' 2>/dev/null || echo 0)

    if [[ "$size" -gt 0 ]]; then
        log_message "🟢  $size  stream(s) ativos – impedindo sleep."
    else
        log_message "⚪  Nenhuma stream ativa – deixando o systemd decidir."
    fi

    echo "$size"
}

while true; do
    active=$(check_plex)

    if (( active > 0 )); then
        if ! has_lock; then
            log_message "Starting inhibitor (active sessions=$active)"
            start_inhibit
        fi
    else
        if has_lock; then
            log_message "No active sessions – releasing inhibitor"
            stop_inhibit
        fi
    fi

    sleep 120  # checa a cada 2 minuto
done
