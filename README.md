<div align="center">

# 🛡️ System Care Pro WSL2 — WebNova Aurora

### Painel Web TUI CSS gráfico para manutenção, diagnóstico e limpeza segura do WSL2 Ubuntu

![Shell](https://img.shields.io/badge/Shell-Bash_4.4%2B-4EAA25?logo=gnu-bash&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-WSL2_Ubuntu-0078D4?logo=windows&logoColor=white)
![Interface](https://img.shields.io/badge/UI-WebNova_Aurora-8A5CF6)
![Localhost](https://img.shields.io/badge/Server-127.0.0.1_only-22C55E)
![Security](https://img.shields.io/badge/Safety-Token_%2B_Explicit_Confirmations-F59E0B)
![No Eval](https://img.shields.io/badge/No-eval-EF4444)

**System Care Pro WSL2** é um script Bash premium com interface Web local para cuidar do WSL2 Ubuntu com foco em segurança, clareza, controle e experiência visual moderna.

Ele combina um **painel gráfico responsivo em CSS**, um **backend local em Bash/Python**, um **catálogo único de ações reais** e um **fallback CLI estável** para diagnóstico, limpeza, caches de desenvolvimento, auditorias e execução em lote.

</div>

---

## ✨ Visão geral

O **System Care Pro WSL2 — WebNova Aurora** foi criado para resolver um problema comum em scripts de manutenção: menus de terminal que piscam, quebram em WSL2, dependem de bibliotecas externas ou deixam opções sem ação real.

Esta versão usa uma abordagem diferente:

- interface principal via **TUI Web CSS local**;
- servidor limitado a **`127.0.0.1`**;
- token de sessão na URL;
- sidebar com todas as funções;
- cards visuais responsivos;
- console real minimizável, maximizável e ocultável;
- confirmação explícita para ações de alto impacto;
- fallback CLI para terminais simples;
- catálogo único de ações compartilhado entre Web e CLI.

O objetivo é entregar uma experiência de manutenção mais bonita, segura e previsível, sem transformar o terminal em uma árvore de Natal piscante. 🛰️

---

## 🧭 Sumário

- [Principais recursos](#-principais-recursos)
- [Interface WebNova Aurora](#-interface-webnova-aurora)
- [Segurança por desenho](#-segurança-por-desenho)
- [Requisitos](#-requisitos)
- [Instalação](#-instalação)
- [Uso rápido](#-uso-rápido)
- [Modos de execução](#-modos-de-execução)
- [Catálogo de ações](#-catálogo-de-ações)
- [Execução em lote](#-execução-em-lote)
- [Arquitetura](#-arquitetura)
- [Variáveis de ambiente](#-variáveis-de-ambiente)
- [Fluxo recomendado de uso](#-fluxo-recomendado-de-uso)
- [Validação e QA](#-validação-e-qa)
- [Solução de problemas](#-solução-de-problemas)
- [Boas práticas antes de executar](#-boas-práticas-antes-de-executar)
- [Limites e decisões conscientes](#-limites-e-decisões-conscientes)
- [Roadmap sugerido](#-roadmap-sugerido)
- [Referências de documentação e design](#-referências-de-documentação-e-design)

---

## 🚀 Principais recursos

### UI/UX premium 2026

- Dashboard Web CSS gráfico com estética **dark-first**.
- Visual Aurora com gradientes controlados, vidro fosco e profundidade leve.
- Cards compactos e escaneáveis.
- Sidebar com todas as funções.
- Busca visual por função.
- Layout responsivo para desktop, tablet e telas menores.
- Console real com estados: normal, minimizado, maximizado e oculto.
- Botão flutuante para restaurar o console.
- Pop-up de confirmação para execução completa.
- Barra de progresso visual.
- Toasts de feedback.
- Atalho `Ctrl+K` para busca.
- Atalho `Esc` para fechar modal ou sair do console maximizado.

### Backend local real

- Servidor local em `127.0.0.1`.
- API local com rotas para status, catálogo e execução.
- Token de sessão para reduzir exposição acidental.
- Execução de ações reais do Bash.
- Saída das ações exibida no console do painel.

### Fallback CLI

- Menu CLI estável para ambientes sem navegador.
- Mesmo catálogo de ações do painel Web.
- Mesmo dispatcher de execução.
- Sem dependência de `gum`, `fzf`, `dialog` ou bibliotecas gráficas externas.

---

## 🌌 Interface WebNova Aurora

A interface foi pensada como um cockpit local de manutenção para WSL2:

| Área | Função |
|---|---|
| **Topbar** | Exibe estado do sistema, execução e botão de ação em lote. |
| **Sidebar** | Lista todas as categorias e funções do script. |
| **Cards** | Mostram ações com ícone, risco, categoria e descrição. |
| **Console real** | Exibe stdout/stderr das ações executadas. |
| **Modal de execução total** | Solicita confirmação textual antes de rodar pacotes maiores. |
| **Status widgets** | Mostram disco, memória, sudo, Docker e engine. |

A experiência visual segue uma linha de design moderna para 2026: interfaces mais modulares, responsivas, acessíveis e com microinterações úteis, sem sacrificar performance.

---

## 🛡️ Segurança por desenho

Este script foi criado para manutenção de ambiente, portanto segurança não é enfeite, é estrutura.

### Proteções principais

- Servidor Web local limitado a `127.0.0.1`.
- Token de sessão na URL.
- Sem `eval`.
- Sem módulos de GRUB/kernel.
- Sem criação de logs permanentes por padrão.
- Ações destrutivas isoladas.
- Confirmações explícitas para operações de alto impacto.
- Docker destrutivo exige confirmação específica.
- Ações regeneráveis exigem confirmação antes de apagar dependências locais.
- Preview disponível para ambientes virtuais e `node_modules` antigos.

### Confirmações exigidas

| Ação | Confirmação |
|---|---|
| Remoção de ambientes virtuais regeneráveis | `APAGAR-REGENERAVEIS` |
| Remoção de `node_modules` antigos | `APAGAR-REGENERAVEIS` |
| Docker destrutivo | `APAGAR-DOCKER` |
| Execução completa pelo painel | `EXECUTAR-TUDO` |

---

## ✅ Requisitos

### Sistema

- Windows com WSL2 ativo.
- Distribuição Ubuntu no WSL2.
- Bash `4.4+`.
- Acesso ao terminal da distribuição.

### Ferramentas esperadas

O script usa ferramentas padrão do Ubuntu/WSL2, como:

- `bash`
- `awk`
- `sed`
- `grep`
- `find`
- `du`
- `df`
- `free`
- `sudo`
- `apt-get`
- `dpkg`
- `python3`

Algumas funções são opcionais e só rodam quando a ferramenta existe, como `docker`, `snap`, `flatpak`, `npm`, `yarn`, `pnpm`, `go`, `dotnet`, `composer`, `conda`, `poetry`, entre outras.

---

## 📦 Instalação

Clone o repositório ou copie o script para uma pasta dentro do WSL2 Ubuntu.

```bash
chmod +x system-care-pro-wsl2-webnova-v8.1-aurora.sh
```

Execute o self-test antes de usar:

```bash
./system-care-pro-wsl2-webnova-v8.1-aurora.sh --self-test
```

Abra o painel:

```bash
./system-care-pro-wsl2-webnova-v8.1-aurora.sh
```

O terminal exibirá uma URL local parecida com:

```text
http://127.0.0.1:8787/?token=valor-exibido-no-terminal
```

Copie a URL e cole no navegador do Windows caso ele não abra automaticamente.

---

## ⚡ Uso rápido

```bash
# 1. Dar permissão de execução
chmod +x system-care-pro-wsl2-webnova-v8.1-aurora.sh

# 2. Validar sem alterar o sistema
./system-care-pro-wsl2-webnova-v8.1-aurora.sh --self-test

# 3. Visualizar catálogo de opções
./system-care-pro-wsl2-webnova-v8.1-aurora.sh --menu-preview

# 4. Abrir painel Web local
./system-care-pro-wsl2-webnova-v8.1-aurora.sh

# 5. Usar fallback CLI
./system-care-pro-wsl2-webnova-v8.1-aurora.sh --cli
```

---

## 🧰 Modos de execução

| Comando | O que faz |
|---|---|
| `./system-care-pro-wsl2-webnova-v8.1-aurora.sh` | Inicia o painel WebNova Aurora em `127.0.0.1`. |
| `./system-care-pro-wsl2-webnova-v8.1-aurora.sh --cli` | Abre menu CLI estável. |
| `./system-care-pro-wsl2-webnova-v8.1-aurora.sh --self-test` | Valida estrutura, catálogo e proteções sem limpar nada. |
| `./system-care-pro-wsl2-webnova-v8.1-aurora.sh --menu-preview` | Lista todas as ações registradas. |
| `./system-care-pro-wsl2-webnova-v8.1-aurora.sh --help` | Mostra ajuda de uso. |

---

## 🧩 Catálogo de ações

A versão WebNova Aurora possui **40 ações reais** registradas em catálogo único.

### Diagnóstico

| ID | Nome | Risco | Descrição |
|---|---|---|---|
| `health_overview` | Diagnóstico geral | leitura | Mostra distro, kernel, disco, memória, uptime, processos e Docker quando disponível. |
| `wsl_diagnostics` | Diagnóstico WSL2 | leitura | Mostra integração WSL, Windows interop, `wsl.conf` e informações do kernel. |
| `network_dns_audit` | Auditoria DNS/rede | leitura | Exibe `resolv.conf`, rotas, hosts e teste DNS leve. |
| `mounts_audit` | Auditoria de mounts | leitura | Mostra mounts relevantes, `/mnt` e filesystem root. |
| `apt_sources_audit` | Auditoria sources APT | leitura | Lista sources do APT sem alterar nada. |
| `largest_offenders` | Maiores ofensores em HOME | leitura | Lista maiores diretórios e arquivos no HOME sem apagar. |
| `reclaim_estimate` | Estimativa recuperável | leitura | Estima tamanho de caches conhecidos sem apagar. |

### Administração e APT

| ID | Nome | Risco | Descrição |
|---|---|---|---|
| `sudo_refresh` | Validar sudo | admin | Renova sessão sudo para ações administrativas. |
| `apt_update` | Atualizar índices APT | admin | Executa `apt-get update` com verificação de lock. |
| `apt_repair` | Reparar APT/DPKG | admin | Executa `dpkg --configure -a` e `apt-get install -f -y`. |
| `apt_upgrade` | Atualizar pacotes | admin | Executa `apt-get upgrade -y`. |
| `apt_cleanup` | Limpar cache APT | admin | Executa `autoremove`, `autoclean`, `clean` e limpa downloads parciais. |

### Limpeza segura

| ID | Nome | Risco | Descrição |
|---|---|---|---|
| `tmp_cleanup` | Limpar temporários seguros | seguro | Remove entradas antigas de `/tmp` e `/var/tmp`. |
| `user_cache_old` | Limpar cache antigo do usuário | seguro | Remove arquivos em `~/.cache` com mais de 30 dias. |
| `thumbnails_cleanup` | Limpar miniaturas | seguro | Esvazia `~/.cache/thumbnails`. |
| `trash_cleanup` | Esvaziar lixeira Linux | seguro | Esvazia `~/.local/share/Trash/files` e `info`. |
| `font_cache` | Reconstruir cache de fontes | seguro | Remove cache fontconfig e executa `fc-cache` quando disponível. |

### Caches de desenvolvimento

| ID | Nome | Risco | Descrição |
|---|---|---|---|
| `pip_cache` | Limpar cache pip | seguro | Executa limpeza de cache do `pip`. |
| `node_cache` | Limpar cache Node | seguro | Limpa caches `npm`, `yarn` e `pnpm`. |
| `python_modern_cache` | Limpar caches Python modernos | seguro | Limpa caches de `uv`, `pipx`, `pipenv`, `pdm`, `hatch` e `rye`. |
| `java_cache` | Limpar caches Java seguros | seguro | Remove caches Gradle regeneráveis e metadados temporários Maven. |
| `go_rust_cache` | Limpar caches Go/Rust | seguro | Executa `go clean` e remove caches seguros do Cargo. |
| `composer_dotnet_cache` | Limpar Composer/.NET | seguro | Executa `composer clear-cache` e `dotnet nuget locals all --clear`. |

### Apps, navegadores e GPU

| ID | Nome | Risco | Descrição |
|---|---|---|---|
| `browser_safe_cache` | Limpar cache seguro de navegadores | seguro | Remove caches regeneráveis de navegadores fechados. |
| `browser_advanced_cache` | Limpar cache avançado de navegadores | atenção | Remove Service Worker CacheStorage, blob storage e File System regeneráveis. |
| `electron_ide_cache` | Limpar IDEs/Electron | seguro | Remove caches regeneráveis de VS Code, VSCodium, JetBrains, Discord, Slack, Obsidian e similares. |
| `gpu_shader_cache` | Limpar shader/GPU cache | seguro | Remove caches Mesa, Vulkan, NVIDIA ComputeCache e GPUCache regeneráveis. |

### Regeneráveis

| ID | Nome | Risco | Descrição |
|---|---|---|---|
| `virtualenv_preview` | Preview de ambientes virtuais | leitura | Lista `venv`, `.venv`, `env`, `.tox`, `.nox` sob HOME sem apagar. |
| `virtualenv_cleanup` | Remover ambientes virtuais regeneráveis | alto | Remove ambientes virtuais regeneráveis após confirmação. |
| `node_modules_preview` | Preview node_modules antigos | leitura | Lista `node_modules` antigos com `package.json` irmão sem apagar. |
| `node_modules_cleanup` | Remover node_modules antigos | alto | Remove `node_modules` antigos após confirmação. |

### Docker

| ID | Nome | Risco | Descrição |
|---|---|---|---|
| `docker_status` | Diagnóstico Docker | leitura | Mostra `docker system df` quando daemon está ativo. |
| `docker_safe_prune` | Docker seguro | seguro | Executa `builder prune` e `network prune`, sem apagar imagens/containers. |
| `docker_destructive_prune` | Docker destrutivo | alto | Executa `docker system prune -a -f` após confirmação. |

### Pacotes universais e sistema

| ID | Nome | Risco | Descrição |
|---|---|---|---|
| `snap_flatpak` | Atualizar Snap/Flatpak | admin | Atualiza Snap/Flatpak e remove revisões/runtimes não usados. |
| `journal_cleanup` | Limpar Journal/crash | admin | Executa `journalctl --vacuum-time=3d` e limpa `/var/crash`. |
| `performance_session` | Performance da sessão WSL2 | admin | Ajusta sysctl de sessão, `drop_caches` e `fstrim`. |

### Execução em lote

| ID | Nome | Risco | Descrição |
|---|---|---|---|
| `all_safe` | Executar pacote seguro | lote | Executa diagnóstico, APT, temporários, caches dev e Docker seguro. |
| `all_fast` | Executar turbo seguro | lote | Executa conjunto rápido seguro sem varreduras longas. |
| `all_complete` | Executar tudo com pop-up | alto | Executa roteiro completo com confirmações explícitas. |

---

## 🚨 Execução em lote

A execução em lote foi criada para reduzir cliques, mas sem retirar controle do usuário.

### Executar pacote seguro

`all_safe` executa um roteiro amplo de ações seguras e administrativas comuns.

### Executar turbo seguro

`all_fast` executa um roteiro mais rápido, sem varreduras longas e sem ações destrutivas.

### Executar tudo com pop-up

`all_complete` abre um modal no painel Web e exige:

```text
EXECUTAR-TUDO
```

Além disso, o usuário escolhe separadamente se deseja incluir:

- remoção de regeneráveis;
- Docker destrutivo.

Essas opções não são ativadas silenciosamente.

---

## 🏗️ Arquitetura

```text
┌─────────────────────────────────────────────────────────────┐
│                    Browser no Windows                       │
│             WebNova Aurora TUI CSS + JavaScript             │
└─────────────────────────────┬───────────────────────────────┘
                              │ HTTP local com token
                              ▼
┌─────────────────────────────────────────────────────────────┐
│             Servidor local 127.0.0.1:<porta>                │
│        API: /api/status | /api/actions | /api/run           │
└─────────────────────────────┬───────────────────────────────┘
                              │ Dispatcher único
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Catálogo de ações                        │
│       IDs, títulos, grupos, riscos, descrições e ícones      │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Funções Bash reais                         │
│  Diagnóstico, APT, caches, Docker, WSL2, auditorias e lotes  │
└─────────────────────────────────────────────────────────────┘
```

### Princípios internos

- Uma ação só aparece se estiver registrada no catálogo.
- A Web UI consome o catálogo via API.
- O CLI também consome o mesmo catálogo.
- O dispatcher é a fonte central de execução.
- O self-test verifica coerência estrutural.

---

## ⚙️ Variáveis de ambiente

| Variável | Exemplo | Finalidade |
|---|---|---|
| `SYSTEM_CARE_PRO_PORT` | `8788` | Define porta alternativa para o painel Web. |
| `SYSTEM_CARE_PRO_NO_BROWSER` | `1` | Impede tentativa automática de abrir navegador. |
| `NO_COLOR` | `1` | Reduz cores no fallback CLI. |
| `SYSTEM_CARE_PRO_ASCII` | `true` | Favorece saída textual simples em terminal limitado. |

Exemplo:

```bash
SYSTEM_CARE_PRO_PORT=8790 SYSTEM_CARE_PRO_NO_BROWSER=1 ./system-care-pro-wsl2-webnova-v8.1-aurora.sh
```

---

## 🧪 Fluxo recomendado de uso

### Primeiro uso

1. Execute o self-test.
2. Abra o painel Web.
3. Clique em **Diagnóstico geral**.
4. Clique em **Validar sudo**.
5. Execute **Estimativa recuperável**.
6. Revise caches grandes antes de remover.
7. Use ações seguras primeiro.
8. Use ações de alto impacto somente quando entender o que será apagado.

### Manutenção semanal

- Diagnóstico geral.
- Atualizar índices APT.
- Limpar cache APT.
- Limpar temporários seguros.
- Limpar cache antigo do usuário.
- Limpar caches dev usados com frequência.
- Docker seguro, se Docker estiver ativo.

### Manutenção pesada

- Preview de ambientes virtuais.
- Preview de `node_modules` antigos.
- Estimativa recuperável.
- Execução completa somente com confirmação consciente.

---

## ✅ Validação e QA

Antes de publicar ou usar uma nova versão, rode:

```bash
bash -n system-care-pro-wsl2-webnova-v8.1-aurora.sh
./system-care-pro-wsl2-webnova-v8.1-aurora.sh --self-test
./system-care-pro-wsl2-webnova-v8.1-aurora.sh --menu-preview
```

Validações esperadas:

- sem erro de sintaxe Bash;
- catálogo carregado;
- ações registradas;
- ausência de `eval`;
- ausência de comandos GRUB/kernel;
- fonte Imprima aplicada na UI Web;
- sidebar encontrada;
- console minimizável/maximizável/ocultável;
- execução total com pop-up encontrada;
- servidor limitado a `127.0.0.1`.

---

## 🧯 Solução de problemas

### O painel não abre no navegador

Copie manualmente a URL exibida no terminal e cole no navegador do Windows.

Também é possível impedir abertura automática:

```bash
SYSTEM_CARE_PRO_NO_BROWSER=1 ./system-care-pro-wsl2-webnova-v8.1-aurora.sh
```

### A porta está em uso

Use outra porta:

```bash
SYSTEM_CARE_PRO_PORT=8790 ./system-care-pro-wsl2-webnova-v8.1-aurora.sh
```

### Ações administrativas falham

Renove a sessão sudo:

```bash
sudo -v
```

Depois abra o painel novamente ou use o botão **Validar sudo**.

### Docker não aparece

Verifique se o daemon Docker está ativo:

```bash
docker info
```

Se Docker Desktop estiver sendo usado, confirme a integração com a distribuição WSL2.

### O navegador mostra erro de token

Use exatamente a URL exibida pelo script, incluindo `?token=...`.

### Terminal sem cores ou emojis

Use modo simples:

```bash
NO_COLOR=1 SYSTEM_CARE_PRO_ASCII=true ./system-care-pro-wsl2-webnova-v8.1-aurora.sh --cli
```

### Quero usar sem interface Web

Use o fallback CLI:

```bash
./system-care-pro-wsl2-webnova-v8.1-aurora.sh --cli
```

---

## 🧠 Boas práticas antes de executar

- Feche navegadores antes de limpar caches de navegador.
- Feche IDEs antes de limpar caches Electron/IDE.
- Faça preview antes de remover `venv`, `.venv` ou `node_modules`.
- Não use Docker destrutivo sem entender o impacto.
- Não rode ações de alto impacto durante builds, installs ou processos importantes.
- Em projetos críticos, faça backup antes de limpezas grandes.
- Leia o console real após cada ação.

---

## 🚧 Limites e decisões conscientes

Este projeto evita algumas ações de propósito.

| Decisão | Motivo |
|---|---|
| Não mexer em GRUB/kernel | WSL2 não deve ser tratado como instalação Linux bare-metal. |
| Não usar `eval` | Reduz risco de execução indesejada. |
| Não criar logs permanentes por padrão | Preserva privacidade e evita sujeira em disco. |
| Não apagar volumes Docker automaticamente | Volumes podem conter dados importantes. |
| Não remover dependências regeneráveis sem confirmação | Evita apagar ambientes de projeto por engano. |
| Não depender de `gum`/`dialog` | Evita problemas de terminal no WSL2. |

---

## 🗺️ Roadmap sugerido

- [ ] Exportação opcional de relatório temporário somente quando o usuário pedir.
- [ ] Modo dry-run global para todas as ações destrutivas.
- [ ] Histórico em memória por sessão no painel.
- [ ] Tema claro opcional.
- [ ] Página dedicada de auditoria Docker.
- [ ] Página dedicada de auditoria Node/Python.
- [ ] Métricas antes/depois por ação.
- [ ] Internacionalização do painel.
- [ ] Testes automatizados em Ubuntu via CI.
- [ ] Publicação de releases versionadas no GitHub.

---

## 🤝 Contribuição

Sugestões são bem-vindas quando preservarem os princípios do projeto:

- segurança primeiro;
- compatibilidade real com WSL2 Ubuntu;
- ações explícitas e auditáveis;
- sem placeholders funcionais;
- sem simulação de limpeza;
- sem comandos destrutivos silenciosos;
- documentação clara;
- UI bonita, mas sem sacrificar estabilidade.

Antes de propor alteração, valide:

```bash
bash -n system-care-pro-wsl2-webnova-v8.1-aurora.sh
./system-care-pro-wsl2-webnova-v8.1-aurora.sh --self-test
```

---

## 🔐 Segurança

Caso encontre comportamento perigoso, ação destrutiva sem confirmação ou exposição indevida do servidor local, trate como prioridade.

Recomendações para o repositório:

- adicionar `SECURITY.md`;
- ativar Dependabot quando houver dependências;
- usar GitHub Code Scanning quando aplicável;
- revisar scripts antes de releases;
- publicar checks mínimos de sintaxe Bash.

---

## 📚 Referências de documentação e design

Este README segue a recomendação do GitHub de explicar por que o projeto é útil, o que ele faz e como usar. Também adota boas práticas de repositório, como instruções de uso, segurança, contribuição e validação.

- GitHub Docs — About READMEs: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes
- GitHub Docs — Best practices for repositories: https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories
- GitHub Docs — Security policy: https://docs.github.com/articles/adding-a-security-policy-to-your-repository
- Awesome README: https://github.com/matiassingers/awesome-readme
- Tenet — UI/UX Design Trends: https://www.wearetenet.com/blog/ui-ux-design-trends
- Figma — Web design trends: https://www.figma.com/resource-library/web-design-trends/

---

## 🛡️ Licença

Defina a licença do projeto no arquivo `LICENSE` do repositório antes de publicar oficialmente.

Enquanto não houver uma licença explícita, o projeto deve ser tratado como código sem licença aberta formal.

---

<div align="center">

**System Care Pro WSL2 — WebNova Aurora**  
Manutenção real, painel bonito e WSL2 respirando melhor. 🌌

</div>
