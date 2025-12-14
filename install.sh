#!/bin/bash

# Script de instalação do Plex Sleep Guardian

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    print_error "Por favor, execute como root (sudo)"
    exit 1
fi

# Diretórios e arquivos
SCRIPT_NAME="plex-sleep-guardian"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc"
CONFIG_FILE="$CONFIG_DIR/plex-sleep-guardian.conf"
SERVICE_FILE="/etc/systemd/system/plex-sleep-guardian.service"
LOG_FILE="/var/log/plex_sleep.log"
SCRIPT_SRC="src/plex-sleep-guardian.sh"

# Verificar dependências
print_info "Verificando dependências..."
for cmd in curl jq systemctl; do
    if ! command -v $cmd &> /dev/null; then
        print_error "$cmd não encontrado. Por favor, instale-o."
        exit 1
    fi
done

# Verificar se o Plex está acessível
print_info "Verificando se o Plex está rodando..."
if ! curl -s http://localhost:32400 > /dev/null; then
    print_warn "Plex não parece estar acessível em localhost:32400"
    print_warn "Certifique-se de que o Plex está rodando e acessível"
fi

# Solicitar token do Plex
get_plex_token() {
    if [ -f "$CONFIG_FILE" ] && grep -q "X_PLEX_TOKEN" "$CONFIG_FILE"; then
        CURRENT_TOKEN=$(grep "X_PLEX_TOKEN" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
        print_info "Token atual encontrado: ${CURRENT_TOKEN:0:4}****"
        read -p "Deseja usar um novo token? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            read -p "Digite o novo token do Plex: " PLEX_TOKEN
        else
            PLEX_TOKEN="$CURRENT_TOKEN"
        fi
    elif [ -n "$PLEX_TOKEN" ]; then
        print_info "Usando token da variável de ambiente PLEX_TOKEN"
    else
        echo ""
        print_info "Para obter o token do Plex:"
        print_info "1. Acesse seu servidor Plex via navegador"
        print_info "2. Navegue até Configurações → Servidor → Geral"
        print_info "3. Em 'Token de autenticação', clique em 'Mostrar token'"
        echo ""
        read -p "Digite o token do Plex: " PLEX_TOKEN
        
        if [ -z "$PLEX_TOKEN" ]; then
            print_error "Token não fornecido. A instalação será cancelada."
            exit 1
        fi
    fi
}

get_plex_token

# Criar arquivo de configuração
print_info "Criando arquivo de configuração em $CONFIG_FILE..."
cat > "$CONFIG_FILE" << EOF
# Configuração do Plex Sleep Guardian
# Este arquivo pode ser editado manualmente

# Token de autenticação do Plex (obrigatório)
X_PLEX_TOKEN="$PLEX_TOKEN"

# Localização do arquivo de log
LOG_FILE="$LOG_FILE"

# Arquivo PID para controle do inhibit
INHIBIT_PID_FILE="/tmp/plex_sleep_guardian.pid"

# Timeout para conexão com o Plex (em segundos)
CURL_TIMEOUT=10

# Endereço do servidor Plex
PLEX_SERVER="http://localhost:32400"
EOF

chmod 644 "$CONFIG_FILE"

# Instalar script principal
print_info "Instalando script em $INSTALL_DIR/$SCRIPT_NAME..."
cp "$SCRIPT_SRC" "$INSTALL_DIR/$SCRIPT_NAME"
chmod 755 "$INSTALL_DIR/$SCRIPT_NAME"

# Substituir variáveis no script
sed -i "s|X_PLEX_TOKEN=.*|X_PLEX_TOKEN=\"\$PLEX_TOKEN\"|" "$INSTALL_DIR/$SCRIPT_NAME"
sed -i "s|source /etc/plex-sleep-guardian.conf|# Config loaded from service|" "$INSTALL_DIR/$SCRIPT_NAME"

# Instalar serviço systemd
print_info "Instalando serviço systemd..."
cp "systemd/plex-sleep-guardian.service" "$SERVICE_FILE"

# Recarregar systemd
print_info "Recarregando systemd..."
systemctl daemon-reload

# Habilitar e iniciar serviço
print_info "Habilitando serviço para iniciar com o sistema..."
systemctl enable plex-sleep-guardian.service

print_info "Iniciando serviço..."
if systemctl start plex-sleep-guardian.service; then
    print_info "Serviço iniciado com sucesso!"
else
    print_error "Falha ao iniciar serviço. Verifique os logs:"
    print_error "journalctl -u plex-sleep-guardian.service -n 50"
    exit 1
fi

# Criar arquivo de log
touch "$LOG_FILE"
chmod 666 "$LOG_FILE" 2>/dev/null || true

print_info "Instalação concluída!"
echo ""
print_info "Comandos úteis:"
print_info "  Ver status: systemctl status plex-sleep-guardian"
print_info "  Ver logs: journalctl -u plex-sleep-guardian -f"
print_info "  Testar: $INSTALL_DIR/$SCRIPT_NAME test"
print_info "  Status: $INSTALL_DIR/$SCRIPT_NAME status"
echo ""
print_info "O token foi salvo em: $CONFIG_FILE"
print_info "Você pode editar as configurações neste arquivo."