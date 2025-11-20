# setup-oracle

Este repositório contém o script `setup_oracle.sh` para auxiliar na preparação/instalação relacionada ao Oracle.

**Sobre**
- **Arquivo:** `setup_oracle.sh` — script principal para realizar a configuração.
- **Local:** `./setup_oracle.sh`

**Requisitos**
- **Shell:** `bash` (Linux)
- **Permissões:** acesso `sudo`/root quando necessário
- **Dependências comuns:** `curl`, `wget`, `unzip` (dependendo do que o script precisa)

**Instalação e uso**
- **Tornar executável:**

```bash
chmod +x setup_oracle.sh
```

- **Executar (modo padrão):**

```bash
sudo ./setup_oracle.sh
```

- **Executar sem sudo (se o script suportar):**

```bash
./setup_oracle.sh
```

**Exemplos**
- Execução simples:

```bash
chmod +x setup_oracle.sh
sudo ./setup_oracle.sh
```

- Para depurar o script (modo verbo):

```bash
bash -x ./setup_oracle.sh
```

**Dicas de solução de problemas**
- `Permission denied`: execute `chmod +x setup_oracle.sh` e tente novamente.
- `Comando não encontrado`: instale a dependência faltante (ex.: `sudo apt install curl`).
- Se a instalação falhar, rode em modo debug `bash -x ./setup_oracle.sh` para ver onde ocorre o erro.

**Onde olhar no script**
- Abra `setup_oracle.sh` para ver variáveis de ambiente exigidas, argumentos aceitos e passos de instalação.

**Licença**
- MIT — sinta-se livre para copiar e adaptar. Inclua atribuição quando apropriado.

**Contato / Manutenção**
- Mantenha este README atualizado quando o `setup_oracle.sh` for alterado.
