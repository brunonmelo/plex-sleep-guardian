#!/bin/bash

# Script de desinstalação do Plex Sleep Guardian

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    print_error "Por favor, execute como root (sudo)"
    exit 1
fi

SERVICE_NAME="plex-sleep-guardian"
INSTALL_DIR="/usr/local/bin"
CONFIG_FILE="/etc/plex-sleep-guardian.conf"
SERVICE_FILE="/etc/systemd/system/plex-sleep-guardian.service"
LOG_FILE="/var/log/plex_sleep.log"

# Parar serviço
if systemctl is-active --quiet "$SERVICE_NAME.service"; then
    print_info "Parando serviço..."
    systemctl stop "$SERVICE_NAME.service"
fi

# Desabilitar serviço
if systemctl is-enabled --quiet "$SERVICE_NAME.service"; then
    print_info "Desabilitando serviço..."
    systemctl disable "$SERVICE_NAME.service"
fi

# Remover arquivos
print_info "Removendo arquivos..."

# Remover script
if [ -f "$INSTALL_DIR/$SERVICE_NAME" ]; then
    rm -f "$INSTALL_DIR/$SERVICE_NAME"
    print_info "Script removido: $INSTALL_DIR/$SERVICE_NAME"
fi

# Remover serviço
if [ -f "$SERVICE_FILE" ]; then
    rm -f "$SERVICE_FILE"
    print_info "Serviço removido: $SERVICE_FILE"
fi

# Remover arquivo de configuração (perguntar)
if [ -f "$CONFIG_FILE" ]; then
    read -p "Deseja remover o arquivo de configuração? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        rm -f "$CONFIG_FILE"
        print_info "Configuração removida: $CONFIG_FILE"
    else
        print_info "Arquivo de configuração mantido: $CONFIG_FILE"
    fi
fi

# Perguntar sobre o arquivo de log
if [ -f "$LOG_FILE" ]; then
    read -p "Deseja remover o arquivo de log? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        rm -f "$LOG_FILE"
        print_info "Log removido: $LOG_FILE"
    else
        print_info "Arquivo de log mantido: $LOG_FILE"
    fi
fi

# Recarregar systemd
systemctl daemon-reload
systemctl reset-failed

print_info "Desinstalação concluída!"