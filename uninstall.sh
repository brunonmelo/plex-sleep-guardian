#!/bin/bash

set -e

SERVICE_NAME="plex-sleep-guardian"
INSTALL_DIR="/usr/local/bin"
CONFIG_FILE="/etc/${SERVICE_NAME}.conf"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo "Por favor, execute como root"
    exit 1
fi

# Parar e desabilitar o serviço
if systemctl is-active --quiet "$SERVICE_NAME"; then
    systemctl stop "$SERVICE_NAME"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME"; then
    systemctl disable "$SERVICE_NAME"
fi

# Remover arquivos
rm -f "$INSTALL_DIR/${SERVICE_NAME}.sh"
rm -f "$CONFIG_FILE"
rm -f "$SERVICE_FILE"

# Recarregar systemd
systemctl daemon-reload

echo "Desinstalação concluída."