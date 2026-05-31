# setup-oracle

Script bash para provisionamento automatizado de servidor web em **Ubuntu 24.04** (Oracle Cloud Infrastructure). Instala e configura MariaDB, Apache e firewalld em um único passo.

## O que o script faz

1. `apt update && apt upgrade`
2. Instala pacotes essenciais (`curl`, `gnupg`, `ca-certificates`, etc.)
3. Instala e endurece o **MariaDB** (`mysql_secure_installation` não-interativo)
4. Configura `bind-address = 0.0.0.0` no MariaDB (acesso remoto)
5. Instala e configura o **Apache** com `ServerName` detectado automaticamente (IP público via metadados OCI ou `ifconfig.me`)
6. Instala o **firewalld** e abre as portas `22`, `80`, `443`, `3306`
7. Oferece criação opcional do usuário `root@'%'` no MariaDB (senha informada interativamente)

## Pré-requisitos

- Ubuntu 24.04
- Acesso `sudo` / root
- Conexão com a internet (para download de pacotes)

## Uso

```bash
chmod +x setup_oracle.sh
sudo ./setup_oracle.sh
```

Para depurar:

```bash
sudo bash -x ./setup_oracle.sh
```

## Portas abertas pelo firewalld

| Porta | Serviço |
|---|---|
| 22 | SSH |
| 80 | HTTP |
| 443 | HTTPS |
| 3306 | MariaDB |

## Autor

Ronaldo Ramires — [LinkedIn](https://linkedin.com/in/ronaldoramires) · [ronaldoramires.xyz](https://ronaldoramires.xyz)