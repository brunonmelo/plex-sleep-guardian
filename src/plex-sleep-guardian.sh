#!/bin/bash
set -euo pipefail

# Carregar configurações
CONFIG_FILE="/etc/plex-sleep-guardian.conf"
if [ -f "$CONFIG_FILE" ]; then
    # Carrega o arquivo de configuração de forma segura
    source "$CONFIG_FILE"
fi

# Usar variável de ambiente se disponível (sobrescreve configuração)
if [ -n "${PLEX_TOKEN:-}" ]; then
    TOKEN="$PLEX_TOKEN"
fi

# Valores padrão
: "${TOKEN:=}"
: "${URL:=http://localhost:32400/status/sessions}"
: "${SLEEP_GUARDIAN_PID_FILE:=/run/plex_sleep_guardian.pid}"
: "${LOG_FILE:=/var/log/plex-sleep-guardian.log}"
: "${CHECK_INTERVAL:=120}"

# Função de logging
log_message() {
    echo "[$(date +"%Y.%m.%d-%T")] $1" >> "$LOG_FILE"
}

# Verificar se já há um lock ativo
has_lock() {
    systemd-inhibit --list --no-pager 2>/dev/null | grep -q 'Plex Sleep Guardian'
}

# Criar lock
start_inhibit() {
    # Evita criar dois locks ao mesmo tempo
    [[ -f "$SLEEP_GUARDIAN_PID_FILE" ]] && return
    
    # Cria o inhibit lock
    systemd-inhibit --what=sleep --who="Plex Sleep Guardian" --why="Plex is streaming" --mode=block sleep infinity &
    
    # Salva o PID
    echo $! > "$SLEEP_GUARDIAN_PID_FILE"
    log_message "Sleep Guardian lock criado com PID: $!"
}

# Remover lock
stop_inhibit() {
    if [[ -f "$SLEEP_GUARDIAN_PID_FILE" ]]; then
        local pid
        pid=$(cat "$SLEEP_GUARDIAN_PID_FILE" 2>/dev/null)
        
        if [ -n "$pid" ] && kill "$pid" 2>/dev/null; then
            log_message "Sleep Guardian lock removido (PID: $pid)"
        else
            log_message "Sleep Guardian lock já estava removido"
        fi
        
        rm -f "$SLEEP_GUARDIAN_PID_FILE"
    fi
}

# Verificar se há streams ativos no Plex
check_plex() {
    # Verificar se o token está configurado
    if [ -z "$PLEX_TOKEN" ]; then
        log_message "❌ ERRO: Token do Plex não configurado"
        log_message "❌ Configure o token em $CONFIG_FILE ou na variável de ambiente PLEX_TOKEN"
        return 1
    fi

    # Fazer requisição para o Plex
    if ! resp=$(curl -s -f \
        -H "X-Plex-Token: $PLEX_TOKEN" \
        -H "Accept: application/json" \
        --connect-timeout 10 \
        --max-time 15 \
        "$URL" 2>/dev/null); then
        log_message "❌ ERRO: Falha ao conectar com o Plex (curl falhou)"
        return 1
    fi

    # Extrair número de sessões ativas
    if ! size=$(echo "$resp" | jq -e -r '.MediaContainer.size' 2>/dev/null); then
        size=0
    fi

    echo "$size"
    return 0
}

# Limpeza ao sair
cleanup() {
    log_message "🛑 Script finalizado - Removendo inhibit lock"
    stop_inhibit
    exit 0
}

# Configurar trap para sinais de término
trap cleanup SIGTERM SIGINT

# Criar arquivo de log se não existir
touch "$LOG_FILE"
chmod 666 "$LOG_FILE" 2>/dev/null || true

log_message "🚀 Plex Sleep Guardian iniciado"
log_message "📋 Configuração: Token=${TOKEN:0:4}****, URL=$URL, Intervalo=$CHECK_INTERVAL"

# Loop principal
while true; do
    if active=$(check_plex); then
        if [[ "$active" -gt 0 ]]; then
            log_message "🟢 $active stream(s) ativo(s)"
            
            if ! has_lock; then
                log_message "   ↳ Criando inhibit lock"
                start_inhibit
            fi
        else
            if has_lock; then
                log_message "⚪ Nenhum stream ativo"
                log_message "   ↳ Removendo inhibit lock"
                stop_inhibit
            fi
        fi
    else
        log_message "⚠️  Falha na verificação - Mantendo estado atual"
    fi

    # Aguardar próximo ciclo
    sleep "$CHECK_INTERVAL"
done