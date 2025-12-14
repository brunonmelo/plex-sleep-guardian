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
LOG_FILE="/var/log/plex-sleep-guardian.log"
SCRIPT_SRC="src/plex-sleep-guardian.sh"

# Verificar dependências
print_info "Verificando dependências..."
for cmd in curl jq systemctl; do
    if ! command -v $cmd &> /dev/null; then
        print_error "'$cmd' não encontrado."
        
        if [ "$cmd" = "jq" ]; then
            print_info "Instale com: sudo apt install jq  # Debian/Ubuntu"
            print_info "            sudo dnf install jq    # Fedora"
            print_info "            sudo pacman -S jq      # Arch"
        fi
        exit 1
    fi
done

# Solicitar token do Plex
get_plex_token() {
    local token_input
    
    # Verificar se já existe configuração
    if [ -f "$CONFIG_FILE" ] && grep -q "^PLEX_TOKEN=" "$CONFIG_FILE"; then
        CURRENT_TOKEN=$(grep "^PLEX_TOKEN=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | head -1)
        print_info "Token atual encontrado: ${CURRENT_TOKEN:0:4}****"
        read -p "Deseja usar um novo token? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            read -p "Digite o novo token do Plex: " token_input
            PLEX_TOKEN="$token_input"
        else
            PLEX_TOKEN="$CURRENT_TOKEN"
            return
        fi
    # Verificar variável de ambiente
    elif [ -n "${PLEX_TOKEN:-}" ]; then
        print_info "Usando token da variável de ambiente PLEX_TOKEN"
        PLEX_TOKEN="$PLEX_TOKEN"
        return
    else
        echo ""
        print_info "=== TOKEN DO PLEX ==="
        print_info "Para obter o token:"
        print_info "1. Acesse seu servidor Plex via navegador"
        print_info "2. Configurações → Servidor → Geral"
        print_info "3. Em 'Token de autenticação', clique em 'Mostrar token'"
        echo ""
        read -p "Digite o token do Plex: " token_input
        
        if [ -z "$token_input" ]; then
            print_error "Token não fornecido. Instalação cancelada."
            exit 1
        fi
        PLEX_TOKEN="$token_input"
    fi
}

# Testar token
test_plex_token() {
    local token="$1"
    
    print_info "Testando conexão com o Plex..."
    
    if ! response=$(curl -s -f \
        -H "X-Plex-Token: $token" \
        -H "Accept: application/json" \
        --connect-timeout 5 \
        "http://localhost:32400/status/sessions" 2>/dev/null); then
        print_warn "⚠️  Não foi possível conectar ao Plex com o token fornecido"
        print_warn "Verifique se:"
        print_warn "1. O Plex está rodando em localhost:32400"
        print_warn "2. O token está correto"
        read -p "Continuar mesmo assim? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 1
        fi
    else
        print_info "✅ Conexão com Plex bem-sucedida!"
    fi
}

# Obter token
get_plex_token

# Testar token (opcional)
test_plex_token "$PLEX_TOKEN"

# Criar arquivo de configuração
print_info "Criando arquivo de configuração em $CONFIG_FILE..."
cat > "$CONFIG_FILE" << EOF
# Configuração do Plex Sleep Guardian
# Edite este arquivo e reinicie o serviço para aplicar mudanças

# Token de autenticação do Plex (OBRIGATÓRIO)
PLEX_TOKEN="$PLEX_TOKEN"

# URL do servidor Plex (altere se necessário)
URL="http://localhost:32400/status/sessions"

# Arquivo PID para controle do inhibit
SLEEP_GUARDIAN_PID_FILE="/run/plex_sleep_guardian.pid"

# Localização do arquivo de log
LOG_FILE="$LOG_FILE"

# Intervalo de verificação em segundos (padrão: 120 = 2 minutos)
CHECK_INTERVAL=120
EOF

chmod 644 "$CONFIG_FILE"

# Instalar script principal
print_info "Instalando script em $INSTALL_DIR/$SCRIPT_NAME..."
cp "$SCRIPT_SRC" "$INSTALL_DIR/$SCRIPT_NAME"
chmod 755 "$INSTALL_DIR/$SCRIPT_NAME"

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
    print_info "✅ Serviço iniciado com sucesso!"
else
    print_error "❌ Falha ao iniciar serviço."
    print_error "Verifique os logs: journalctl -u plex-sleep-guardian.service -n 50"
    exit 1
fi

# Criar arquivo de log
touch "$LOG_FILE"
chmod 666 "$LOG_FILE" 2>/dev/null || true

# Verificar status
print_info "Aguardando 3 segundos para verificar status..."
sleep 3

if systemctl is-active --quiet plex-sleep-guardian.service; then
    print_info "✅ Serviço está ativo e rodando!"
else
    print_error "❌ Serviço não está rodando."
    print_error "Verifique o status: sudo systemctl status plex-sleep-guardian"
    print_error "Verifique os logs: sudo journalctl -u plex-sleep-guardian -n 30"
    exit 1
fi

# Instalação concluída
print_info "========================================="
print_info "✅ INSTALAÇÃO CONCLUÍDA!"
print_info "========================================="
echo ""
print_info "📋 COMANDOS ÚTEIS:"
print_info "  Ver status:   sudo systemctl status plex-sleep-guardian"
print_info "  Ver logs:     sudo journalctl -u plex-sleep-guardian -f"
print_info "  Log do script: sudo tail -f $LOG_FILE"
print_info "  Reiniciar:    sudo systemctl restart plex-sleep-guardian"
echo ""
print_info "⚙️  CONFIGURAÇÃO:"
print_info "  Arquivo de configuração: $CONFIG_FILE"
print_info "  Token salvo: ${PLEX_TOKEN:0:4}****"
print_info "  Você pode editar as configurações e reiniciar o serviço."
echo ""
print_info "🔍 VERIFICAÇÃO:"
print_info "  Verificar inhibits ativos: systemd-inhibit --list"