#!/bin/bash
set -euo pipefail

# setup_auto_firewalld_ubuntu2404.sh
# Automatiza instalação/configuração conforme pedido:
# - apt -y para todos os pacotes
# - firewalld: libera 22,80,443,3306
# - MariaDB: configura bind-address e parâmetros, opcionalmente cria root@'%' com senha informada interativamente
# - Apache: adiciona ServerName detectando IP, ajusta dir.conf
# Requer execução como root (sudo).

SCRIPT_NAME="$(basename "$0")"

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Execute este script com sudo: sudo ./$SCRIPT_NAME"
    exit 1
  fi
}

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp -a "$f" "${f}.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

detect_public_ip() {
  # Tenta metadados OCI
  local ip
  ip=$(curl -s --connect-timeout 2 "http://169.254.169.254/opc/v1/vnics/" 2>/dev/null || true)
  if [[ -n "$ip" ]]; then
    ip=$(echo "$ip" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1 || true)
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  fi

  # Tenta serviços públicos
  ip=$(curl -s --connect-timeout 5 http://ifconfig.me || true)
  if [[ -n "$ip" ]]; then
    echo "$ip"
    return 0
  fi

  # Fallback: IP local (primeiro IP não loopback)
  ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
  if [[ -n "$ip" ]]; then
    echo "$ip"
    return 0
  fi

  echo "0.0.0.0"
  return 0
}

# Função simples de prompt yes/no
prompt_yes_no() {
  local msg="$1"
  local ans
  while true; do
    read -rp "$msg (y/n): " ans
    case "$ans" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Resposta inválida. Digite y ou n." ;;
    esac
  done
}

# --- início ---
ensure_root

echo "==== Inicio: instalação automática (apt -y) e configurações (firewalld, mariadb, apache) ===="

echo "[1/8] apt update && apt upgrade (automático)"
apt update -y
apt upgrade -y

echo "[2/8] Instalando pacotes essenciais"
apt install -y apt-transport-https curl gnupg lsb-release ca-certificates software-properties-common

echo "[3/8] Instalando MariaDB"
apt install -y mariadb-server

echo "[4/8] Executando mysql_secure_installation automaticamente (interativo limitado)"
(
  mysql -u root <<'SQL' || true
-- remove anonymous users
DELETE FROM mysql.user WHERE User='';
-- remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL
) || true

echo "[5/8] Configurando arquivo MariaDB: /etc/mysql/mariadb.conf.d/50-server.cnf"
CONF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"
backup_file "$CONF_FILE"

if grep -q "^bind-address" "$CONF_FILE" 2>/dev/null; then
  sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" "$CONF_FILE"
else
  if grep -q "^\[mysqld\]" "$CONF_FILE"; then
    awk 'BEGIN{added=0} {print} /^\[mysqld\]/{ if(!added){ print "bind-address = 0.0.0.0"; added=1 }}' "$CONF_FILE" > "${CONF_FILE}.tmp" && mv "${CONF_FILE}.tmp" "$CONF_FILE"
  else
    echo -e "[mysqld]\nbind-address = 0.0.0.0" >> "$CONF_FILE"
  fi
fi

replace_or_append_mysqld_option() {
  local key="$1"
  local val="$2"
  if grep -qE "^[[:space:]]*$key" "$CONF_FILE"; then
    sed -i "s#^[[:space:]]*$key.*#${key} = ${val}#" "$CONF_FILE"
  else
    if grep -q "^\[mysqld\]" "$CONF_FILE"; then
      awk -v k="$key" -v v="$val" 'BEGIN{p=0} {print} /^\[mysqld\]/{p=1; next} END{ if(p==1) print k " = " v }' "$CONF_FILE" > "${CONF_FILE}.tmp" && mv "${CONF_FILE}.tmp" "$CONF_FILE"
    else
      echo -e "[mysqld]\n${key} = ${val}" >> "$CONF_FILE"
    fi
  fi
}

replace_or_append_mysqld_option "binlog_format" "MIXED"
replace_or_append_mysqld_option "max_allowed_packet" "256M"
replace_or_append_mysqld_option "wait_timeout" "28800"
replace_or_append_mysqld_option "interactive_timeout" "28800"
replace_or_append_mysqld_option "lower_case_table_names" "1"
replace_or_append_mysqld_option "innodb_strict_mode" "0"

echo "Configuração MariaDB atualizada. Backup em ${CONF_FILE}.bak*"

echo "[6/8] Reiniciando MariaDB"
systemctl restart mariadb || systemctl restart mysql || true

# ====== ALTERAÇÃO SOLICITADA: NÃO GRAVAR SENHA NO SCRIPT ======
echo "[7/8] Criar/atualizar usuário root@'%' para acesso remoto"
if prompt_yes_no "Deseja criar/atualizar root@'%' agora e digitar a senha interativamente?"; then
  # pede senha interativamente (não fica gravada no script)
  read -rsp "Digite a senha para root@'%': " ROOT_PWD
  echo
  # Confirmação simples
  if [[ -z "$ROOT_PWD" ]]; then
    echo "Senha vazia. Pulando criação do usuário root@'%'."
  else
    mysql -u root <<SQL
DROP USER IF EXISTS 'root'@'%';
CREATE USER 'root'@'%' IDENTIFIED BY '${ROOT_PWD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '${ROOT_PWD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${ROOT_PWD}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
-- bloqueio e desbloqueio de tabelas conforme pedido
FLUSH TABLES WITH READ LOCK;
UNLOCK TABLES;
SQL
    echo "Usuário root@'%' criado/atualizado."
  fi
else
  echo "Pulando criação do usuário root@'%'."
  cat <<'INSTR'
Se preferir criar manualmente depois, execute no MySQL:

sudo mysql -u root -p
-- no prompt mysql:
CREATE USER 'root'@'%' IDENTIFIED BY 'SUA_SENHA_AQUI';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
-- opcionalmente:
GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY 'SUA_SENHA_AQUI';
FLUSH PRIVILEGES;

INSTR
fi
# ====== fim da alteração ======

echo "[8/8] Instalando Apache2, PHP e phpMyAdmin"
apt install -y apache2 php libapache2-mod-php php-mysql php-mbstring phpmyadmin

SERVER_IP="$(detect_public_ip)"
APACHE_CONF="/etc/apache2/apache2.conf"
backup_file "$APACHE_CONF"

if grep -q "^ServerName" "$APACHE_CONF" 2>/dev/null; then
  sed -i "s/^ServerName.*/ServerName ${SERVER_IP}/" "$APACHE_CONF"
else
  echo -e "\n# Diretiva ServerName\nServerName ${SERVER_IP}\n" >> "$APACHE_CONF"
fi

DIR_CONF="/etc/apache2/mods-enabled/dir.conf"
backup_file "$DIR_CONF"

cat > "$DIR_CONF" <<'DIRCONF'
<IfModule mod_dir.c>
       DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm
</IfModule>
DIRCONF

systemctl restart apache2 || true

echo "Instalando e configurando firewalld (abrindo portas 22,80,443,3306)"
apt install -y firewalld
systemctl enable --now firewalld

firewall-cmd --zone=public --permanent --add-port=22/tcp
firewall-cmd --zone=public --permanent --add-port=80/tcp
firewall-cmd --zone=public --permanent --add-port=443/tcp
firewall-cmd --zone=public --permanent --add-port=3306/tcp
firewall-cmd --reload

iptables -I INPUT -p tcp --dport 3306 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT || true
iptables -I OUTPUT -p tcp --sport 3306 -m conntrack --ctstate ESTABLISHED -j ACCEPT || true

systemctl restart mariadb || systemctl restart mysql || true
systemctl restart apache2 || true

echo
echo "==== Concluído ===="
echo "MariaDB configurado para bind-address=0.0.0.0."
echo "Se criou root@'%' com senha, ela foi digitada interativamente (não está gravada neste arquivo)."
echo "Apache ServerName definido como: ${SERVER_IP}"
echo "Firewalld aberto nas portas: 22,80,443,3306 (zona public)."
echo
echo "IMPORTANTE: Também é necessário liberar as mesmas portas na Console OCI (Security Lists ou NSG)."
echo "Backups dos arquivos originais foram criados como *.bak.TIMESTAMP"

exit 0
