# Plex Sleep Guardian

Um serviço systemd que impede a suspensão do sistema enquanto há streams ativos no Plex Media Server.

## 🚀 Funcionalidades

- ✅ Verifica a cada 2 minutos se há streams ativos no Plex
- ✅ Bloqueia automaticamente a suspensão do sistema durante streams
- ✅ Permite suspensão automática quando não há atividade
- ✅ Logs detalhados para monitoramento
- ✅ Configuração flexível via arquivo ou variáveis de ambiente
- ✅ Integração nativa com systemd
- ✅ Reinicialização automática em caso de falhas

## 📦 Requisitos

- **Sistema Operacional**: Linux com systemd
- **Serviços**:
  - Plex Media Server instalado localmente
  - systemd (presente na maioria das distribuições modernas)
- **Dependências**:
  - `curl` - Para fazer requisições HTTP
  - `jq` - Para processar JSON
- **Privilégios**: Acesso root (sudo) para instalação

## 🔧 Instalação

### Método 1: Instalação Padrão

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/plex-sleep-guardian.git
cd plex-sleep-guardian

# Dê permissões de execução
chmod +x install.sh uninstall.sh

# Execute o instalador
sudo ./install.sh
```

### Método 2: Instalação com Token Pré-definido

```bash
sudo PLEX_TOKEN="seu_token_aqui" ./install.sh
```

### Método 2: Instalação com Token Pré-definido

```bash
echo "seu_token_aqui" | sudo ./install.sh
```

Durante a instalação padrão, você será solicitado a inserir o token do Plex.

## 🔑 Como Obter o Token do Plex
[Siga essa documentação para recuperar o token do Plex](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/)

## 🎮 Uso

### Controle do Serviço Systemd

```bash
# Verificar status do serviço
sudo systemctl status plex-sleep-guardian

# Iniciar o serviço
sudo systemctl start plex-sleep-guardian

# Parar o serviço
sudo systemctl stop plex-sleep-guardian

# Reiniciar o serviço
sudo systemctl restart plex-sleep-guardian

# Habilitar inicialização automática
sudo systemctl enable plex-sleep-guardian

# Desabilitar inicialização automática
sudo systemctl disable plex-sleep-guardian

# Ver logs em tempo real
sudo journalctl -u plex-sleep-guardian -f

# Ver logs específicos
sudo journalctl -u plex-sleep-guardian --since "1 hour ago"
```

### Comandos do Script Principal

```bash
# Testar conexão com o Plex
sudo plex-sleep-guardian test

# Verificar status do inhibit
sudo plex-sleep-guardian status

# Parar inhibit manualmente
sudo plex-sleep-guardian stop

# Limpar arquivos temporários
sudo plex-sleep-guardian clean

# Ver configuração atual
sudo plex-sleep-guardian config

# Executar verificação manual
sudo plex-sleep-guardian check
```

### Verificação do Funcionamento

```bash
# Verificar logs do script
sudo tail -f /var/log/plex-sleep-guardian.log

# Verificar inhibits ativos
systemd-inhibit --list

# Verificar se o processo está rodando
ps aux | grep plex-sleep-guardian
```

## ⚙️ Configuração

### Localização dos Arquivos de Configuração

| Arquivo                       | Descrição              | Permissões |
| ----------------------------- | ---------------------- | ---------- |
| /etc/plex-sleep-guardian.conf | Configuração principal | 644 (root) |
| /var/log/plex_sleep.log       | Logs do serviço        | 666        |
| /tmp/plex_sleep_guardian.pid  | PID do processo ativo  | 644        |

### Hierarquia de Configuração (Ordem de Prioridade)

1. Arquivo de configuração (`/etc/plex-sleep-guardian.conf`)
2. Variável de ambiente (`PLEX_TOKEN`)
3. Valor padrão (se definido no script)

### Exemplo de Arquivo de Configuração
```bash
# Configuração do Plex Sleep Guardian
# Edite este arquivo e reinicie o serviço para aplicar mudanças

# Token de autenticação do Plex (OBRIGATÓRIO)
PLEX_TOKEN="seu_token_aqui"

# Localização do arquivo de log
LOG_FILE="/var/log/plex-sleep-guardian.log"

# Arquivo PID para controle do inhibit
SLEEP_GUARDIAN_PID_FILE="/run/plex_sleep_guardian.pid"

# Intervalo de verificação em segundos (padrão: 120 = 2 minutos)
CHECK_INTERVAL=120

# URL do servidor Plex (altere se necessário)
URL="http://localhost:32400/status/sessions"
```

### Atualizando a Configuração
```bash
# 1. Edite o arquivo de configuração
sudo nano /etc/plex-sleep-guardian.conf

# 2. Reinicie o serviço
sudo systemctl restart plex-sleep-guardian

# 3. Verifique se está funcionando
sudo tail -f /var/log/plex-sleep-guardian.log
```

## 🗑️ Desinstalação
```bash
# Navegue até o diretório do projeto
cd plex-sleep-guardian

# Execute o desinstalador
sudo ./uninstall.sh
```

### Opções durante a desinstalação:
- ✅ Remove o script principal
- ✅ Remove o serviço systemd
- 🟡 Pergunta sobre remover configurações
- 🟡 Pergunta sobre remover logs
- ✅ Recarrega o systemd

Para remoção completa sem prompts:

yes | sudo ./uninstall.sh

## 🔍 Troubleshooting

### Problemas Comuns

1. Serviço não inicia
```bash
# Verifique os logs do systemd
sudo journalctl -u plex-sleep-guardian -n 50

# Teste manualmente
sudo plex-sleep-guardian test
```

2. Token inválido ou expirado
```bash
# Teste o token manualmente
curl "http://localhost:32400/status/sessions?X-Plex-Token=SEU_TOKEN"

# Atualize o token
sudo nano /etc/plex-sleep-guardian.conf
sudo systemctl restart plex-sleep-guardian
```

3. Plex não está acessível
```bash
# Verifique se o Plex está rodando
systemctl status plexmediaserver

# Teste a conectividade
curl -v http://localhost:32400

# Verifique a porta
netstat -tlnp | grep 32400
```

4. Script para de funcionar
```bash
# Verifique se há múltiplas instâncias
ps aux | grep "plex-sleep-guardian" | grep -v grep

# Verifique permissões do arquivo de log
ls -la /var/log/plex-sleep-guardian.log

# Reinicie o serviço
sudo systemctl restart plex-sleep-guardian
```

### Comandos de Diagnóstico
```bash
# Verificar inhibits ativos no sistema
systemd-inhibit --list

# Verificar se há processos sleep infinity
ps aux | grep "sleep infinity"

# Monitorar conexões com o Plex
sudo tcpdump -i any port 32400 -n -c 10

# Testar token com output completo
curl -v -H "X-Plex-Token: SEU_TOKEN" http://localhost:32400/status/sessions
```

### Logs Importantes
```bash
# Logs do serviço (systemd)
sudo journalctl -u plex-sleep-guardian -f

# Logs do script (arquivo)
sudo tail -f /var/log/plex-sleep-guardian.log

# Logs do Plex
tail -f "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Logs/Plex Media Server.log"
```

## 📁 Estrutura de Arquivos

```text
plex-sleep-guardian/
├── README.md                    # Esta documentação
├── install.sh                   # Script de instalação
├── uninstall.sh                 # Script de desinstalação
├── src/
│   └── plex-sleep-guardian.sh  # Script principal
└── systemd/
    └── plex-sleep-guardian.service  # Configuração do serviço
```

### Após Instalação
```text
Sistema de arquivos:
├── /usr/local/bin/plex-sleep-guardian          # Script principal
├── /etc/systemd/system/plex-sleep-guardian.service  # Serviço
├── /etc/plex-sleep-guardian.conf               # Configurações
├── /var/log/plex-sleep-guardian.log            # Logs
└── /run/plex_sleep_guardian.pid                # PID do processo
```

## 🤝 Contribuição
Contribuições são bem-vindas! Siga estes passos:

1. Fork o repositório
2. Crie uma branch para sua feature:
```bash
git checkout -b minha-feature
```
3. Commit suas mudanças:
```bash
git commit -m "Adiciona nova funcionalidade"
```
4. Push para a branch:
```
git push origin minha-feature
```
5. Abra um Pull Request

### Diretrizes de Desenvolvimento
- Use nomes descritivos para commits
- Mantenha o código compatível com Bash 4+
- Teste em diferentes distribuições Linux
- Documente novas funcionalidades no README

## 📄 Licença
Este projeto está licenciado sob a licença MIT.

---

Nota: Este projeto não é afiliado oficialmente com a Plex, Inc. "Plex" é uma marca registrada da Plex, Inc.
