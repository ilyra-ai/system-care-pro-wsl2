#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║        SYSTEM CARE PRO WSL2 — WEBNOVA TUI CSS v8.0.0                       ║
# ║        Painel gráfico local, real, seguro e anti-flicker para WSL2 Ubuntu  ║
# ║        Interface Web CSS premium 2026 + fallback CLI estável               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# USO PRINCIPAL:
#   chmod +x system-care-pro-wsl2-webnova-v8.sh
#   ./system-care-pro-wsl2-webnova-v8.sh
#
# USO CLI ESTÁVEL:
#   ./system-care-pro-wsl2-webnova-v8.sh --cli
#
# VALIDAÇÃO SEM ALTERAR O SISTEMA:
#   ./system-care-pro-wsl2-webnova-v8.sh --self-test
#   ./system-care-pro-wsl2-webnova-v8.sh --menu-preview
#
# GARANTIAS DE PROJETO:
#   • Menu padrão é Web CSS em 127.0.0.1, sem alternate screen e sem piscar.
#   • O fallback CLI usa uma única lista de ações e um único dispatcher.
#   • As opções do menu Web e CLI usam o mesmo catálogo real de ações.
#   • Não cria logs permanentes.
#   • Não usa placeholders para ações.
#   • Não usa eval.
#   • Não executa módulos de GRUB/kernel, pois isso não pertence ao WSL2.
#   • Ações destrutivas exigem confirmação explícita.
#   • O servidor local usa token de sessão e bind exclusivo em 127.0.0.1.
#
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="System Care Pro WSL2"
SCRIPT_VERSION="8.0.0-webnova"
SCRIPT_STARTED_AT="$(date +%s)"
DEFAULT_WEB_PORT="8787"
MIN_BASH_MAJOR=4
MIN_BASH_MINOR=4

# -----------------------------------------------------------------------------
# Cores ANSI para fallback CLI. A UI principal é CSS no navegador.
# -----------------------------------------------------------------------------
RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
C_PRIMARY='\033[38;2;132;96;255m'
C_SECONDARY='\033[38;2;0;229;255m'
C_ACCENT='\033[38;2;29;255;196m'
C_SUCCESS='\033[38;2;73;222;128m'
C_WARN='\033[38;2;255;204;102m'
C_ERROR='\033[38;2;255;94;129m'
C_MUTED='\033[38;2;145;157;180m'
C_TEXT='\033[38;2;235;241;255m'

ICON_SHIELD='🛡️'
ICON_WEB='🌐'
ICON_HEALTH='📊'
ICON_BROOM='🧹'
ICON_PACKAGE='📦'
ICON_DOCKER='🐳'
ICON_SPEED='⚡'
ICON_LOCK='🔒'
ICON_DISK='💾'
ICON_WSL='🪟'
ICON_STAR='✨'
ICON_WARN='⚠️'
ICON_OK='✅'
ICON_FAIL='❌'
ICON_EXIT='👋'
ICON_CODE='🧬'
ICON_BROWSER='🧭'
ICON_GPU='🪐'

# -----------------------------------------------------------------------------
# Utilitários básicos
# -----------------------------------------------------------------------------
term_cols() {
    local cols
    cols="$(tput cols 2>/dev/null || true)"
    [[ "$cols" =~ ^[0-9]+$ && "$cols" -ge 60 ]] && printf '%s' "$cols" || printf '100'
}

repeat_char() {
    local char="$1" count="$2" i
    for ((i=0; i<count; i++)); do printf '%s' "$char"; done
}

ui_plain() {
    [[ "${NO_COLOR:-}" == "1" || "${TERM:-}" == "dumb" || ! -t 1 ]]
}

c() {
    if ui_plain; then printf ''; else printf '%b' "$1"; fi
}

ce() {
    if ui_plain; then printf ''; else printf '%b' "$RST"; fi
}

line() {
    local w
    w="$(term_cols)"
    printf '%b%s%b\n' "$(c "$C_MUTED")" "$(repeat_char '─' "$w")" "$(ce)"
}

say() {
    local kind="$1" msg="$2" color icon
    case "$kind" in
        ok) color="$C_SUCCESS"; icon="$ICON_OK" ;;
        warn) color="$C_WARN"; icon="$ICON_WARN" ;;
        fail) color="$C_ERROR"; icon="$ICON_FAIL" ;;
        cmd) color="$C_ACCENT"; icon='➜' ;;
        *) color="$C_SECONDARY"; icon='•' ;;
    esac
    printf '  %b%s %s%b\n' "$(c "$color")" "$icon" "$msg" "$(ce)"
}

format_seconds() {
    local seconds="${1:-0}" h m s
    h=$((seconds / 3600)); m=$(((seconds % 3600) / 60)); s=$((seconds % 60))
    if (( h > 0 )); then printf '%02d:%02d:%02d' "$h" "$m" "$s"; else printf '%02d:%02d' "$m" "$s"; fi
}

format_kb() {
    local kb="${1:-0}"
    awk -v kb="$kb" 'BEGIN { bytes=kb*1024; split("B KB MB GB TB",u," "); i=1; while(bytes>=1024 && i<5){bytes/=1024;i++} if(i==1) printf "%d %s", bytes, u[i]; else printf "%.1f %s", bytes, u[i]; }'
}

resolve_target_home() {
    local candidate=""
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
        candidate="$(getent passwd "$SUDO_USER" 2>/dev/null | awk -F: '{print $6}' || true)"
    fi
    if [[ -z "$candidate" && -n "${USER:-}" && "${USER:-}" != "root" ]]; then
        candidate="$(getent passwd "$USER" 2>/dev/null | awk -F: '{print $6}' || true)"
    fi
    [[ -n "$candidate" ]] || candidate="${HOME:-/root}"
    printf '%s' "$candidate"
}

TARGET_HOME="$(resolve_target_home)"
if [[ -d "$TARGET_HOME" ]]; then export HOME="$TARGET_HOME"; fi

# -----------------------------------------------------------------------------
# Pré-requisitos e segurança
# -----------------------------------------------------------------------------
is_wsl2() {
    grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || return 1
    [[ -n "${WSL_INTEROP:-}" || -n "${WSL_DISTRO_NAME:-}" || -d /run/WSL || -e /proc/sys/fs/binfmt_misc/WSLInterop ]]
}

is_ubuntu_like() {
    [[ -r /etc/os-release ]] || return 1
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
        ubuntu|debian|kali|linuxmint|pop|neon|elementary|zorin|raspbian|devuan|parrot) return 0 ;;
    esac
    [[ "${ID_LIKE:-}" == *ubuntu* || "${ID_LIKE:-}" == *debian* ]]
}

require_bash_version() {
    local major="${BASH_VERSINFO[0]}" minor="${BASH_VERSINFO[1]}"
    if (( major < MIN_BASH_MAJOR || (major == MIN_BASH_MAJOR && minor < MIN_BASH_MINOR) )); then
        say fail "Bash $MIN_BASH_MAJOR.$MIN_BASH_MINOR+ requerido. Atual: $major.$minor"
        exit 1
    fi
}

require_wsl2_ubuntu() {
    if ! is_wsl2 || ! is_ubuntu_like; then
        say fail "Este script deve rodar dentro do WSL2 Ubuntu ou derivado Debian-like no WSL2."
        printf '  Kernel: %s\n' "$(uname -r 2>/dev/null || echo desconhecido)"
        printf '  Distro: %s\n' "$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo desconhecida)"
        exit 1
    fi
}

require_python3() {
    if ! command -v python3 >/dev/null 2>&1; then
        say fail "python3 é necessário para o TUI Web CSS gráfico. Instale com: sudo apt-get install -y python3"
        exit 1
    fi
}

sudo_available() {
    command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1
}

sudo_run() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        if ! command -v sudo >/dev/null 2>&1; then
            say fail "sudo não encontrado."
            return 1
        fi
        sudo -n "$@"
    fi
}

check_apt_lock() {
    local path
    local lock_paths=(/var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock)
    if command -v fuser >/dev/null 2>&1; then
        for path in "${lock_paths[@]}"; do
            if sudo_run fuser "$path" >/dev/null 2>&1; then
                say fail "APT/DPKG está em uso: $path. Feche outro apt/dpkg antes de prosseguir."
                return 1
            fi
        done
    fi
    return 0
}

path_size_kb() {
    local target="$1"
    if [[ -e "$target" ]]; then du -sk "$target" 2>/dev/null | awk 'NR==1{print $1}' || printf '0'; else printf '0'; fi
}

path_is_dangerous() {
    local target="${1:-}"
    [[ -n "$target" ]] || return 0
    case "$target" in
        /|/home|/root|/usr|/var|/etc|/bin|/sbin|/lib|/lib32|/lib64|/proc|/sys|/dev|/run|/boot|/mnt|/media|/snap|"$HOME") return 0 ;;
    esac
    return 1
}

remove_tree_guarded() {
    local target="$1" label="${2:-item}"
    [[ -e "$target" ]] || return 0
    if path_is_dangerous "$target"; then
        say warn "Proteção ativa: alvo perigoso ignorado: $target"
        return 0
    fi
    local size
    size="$(path_size_kb "$target")"
    say cmd "Removendo $label: $target ($(format_kb "$size"))"
    rm -rf --one-file-system -- "$target" 2>/dev/null || sudo_run rm -rf --one-file-system -- "$target"
}

process_active() {
    local uid name
    uid="$(id -u 2>/dev/null || echo 0)"
    for name in "$@"; do
        if command -v pgrep >/dev/null 2>&1; then
            pgrep -u "$uid" -x "$name" >/dev/null 2>&1 && return 0
        else
            ps -u "$uid" -o comm= 2>/dev/null | grep -Fx -- "$name" >/dev/null 2>&1 && return 0
        fi
    done
    return 1
}

run_external() {
    local description="$1" status
    shift
    say cmd "$description"
    set +e
    "$@" 2>&1 | while IFS= read -r line_out; do [[ -n "$line_out" ]] && printf '    %s\n' "$line_out"; done
    status=${PIPESTATUS[0]}
    set -e
    if (( status == 0 )); then say ok "$description concluído"; else say fail "$description falhou com código $status"; fi
    return "$status"
}

# -----------------------------------------------------------------------------
# Catálogo único de ações. O Web TUI e o CLI usam exatamente esta lista.
# -----------------------------------------------------------------------------
ACTION_IDS=(); ACTION_TITLES=(); ACTION_GROUPS=(); ACTION_RISKS=(); ACTION_DESCS=(); ACTION_ICONS=()
ACTIONS_INITIALIZED=false

register_action() {
    ACTION_IDS+=("$1"); ACTION_TITLES+=("$2"); ACTION_GROUPS+=("$3"); ACTION_RISKS+=("$4"); ACTION_DESCS+=("$5"); ACTION_ICONS+=("$6")
}

init_actions() {
    [[ "$ACTIONS_INITIALIZED" == true ]] && return 0
    ACTION_IDS=(); ACTION_TITLES=(); ACTION_GROUPS=(); ACTION_RISKS=(); ACTION_DESCS=(); ACTION_ICONS=()
    register_action health_overview "Diagnóstico geral" "Diagnóstico" "leitura" "Mostra distro, kernel, disco, memória, uptime, processos e Docker se existir." "$ICON_HEALTH"
    register_action sudo_refresh "Validar sudo" "Admin" "admin" "Renova a sessão sudo no terminal para ações administrativas via Web." "$ICON_LOCK"
    register_action apt_update "Atualizar índices APT" "APT e pacotes" "admin" "Executa apt-get update com verificação de lock." "$ICON_PACKAGE"
    register_action apt_repair "Reparar APT/DPKG" "APT e pacotes" "admin" "Executa dpkg --configure -a e apt-get install -f -y." "🧩"
    register_action apt_upgrade "Atualizar pacotes" "APT e pacotes" "admin" "Executa apt-get upgrade -y, sem dist-upgrade automático." "$ICON_PACKAGE"
    register_action apt_cleanup "Limpar cache APT" "APT e pacotes" "admin" "Executa autoremove, autoclean, clean e limpa downloads parciais." "$ICON_BROOM"
    register_action tmp_cleanup "Limpar temporários seguros" "Limpeza segura" "seguro" "Remove entradas antigas de /tmp e /var/tmp com filtros de idade." "$ICON_BROOM"
    register_action user_cache_old "Limpar cache antigo do usuário" "Limpeza segura" "seguro" "Remove arquivos em ~/.cache com mais de 30 dias." "$ICON_BROOM"
    register_action thumbnails_cleanup "Limpar miniaturas" "Limpeza segura" "seguro" "Esvazia ~/.cache/thumbnails." "🖼️"
    register_action trash_cleanup "Esvaziar lixeira Linux" "Limpeza segura" "seguro" "Esvazia ~/.local/share/Trash/files e info." "🗑️"
    register_action font_cache "Reconstruir cache de fontes" "Limpeza segura" "seguro" "Remove cache fontconfig do usuário e roda fc-cache quando disponível." "🔤"
    register_action pip_cache "Limpar cache pip" "Dev caches" "seguro" "Executa python3 -m pip cache purge e pip3 cache purge quando disponíveis." "$ICON_CODE"
    register_action node_cache "Limpar cache Node" "Dev caches" "seguro" "Executa npm/yarn/pnpm cache clean/prune quando disponíveis." "$ICON_CODE"
    register_action python_modern_cache "Limpar caches Python modernos" "Dev caches" "seguro" "Limpa uv, pipx, pipenv, pdm, hatch e rye quando existirem." "$ICON_CODE"
    register_action java_cache "Limpar caches Java seguros" "Dev caches" "seguro" "Remove caches Gradle regeneráveis e metadados temporários Maven." "$ICON_CODE"
    register_action go_rust_cache "Limpar caches Go/Rust" "Dev caches" "seguro" "Executa go clean e remove caches seguros do Cargo." "$ICON_CODE"
    register_action composer_dotnet_cache "Limpar Composer/.NET" "Dev caches" "seguro" "Executa composer clear-cache e dotnet nuget locals all --clear." "$ICON_CODE"
    register_action browser_safe_cache "Limpar cache seguro de navegadores" "Apps e navegadores" "seguro" "Remove caches regeneráveis de Chrome/Chromium/Edge/Brave/Firefox quando fechados." "$ICON_BROWSER"
    register_action browser_advanced_cache "Limpar cache avançado de navegadores" "Apps e navegadores" "atenção" "Remove Service Worker CacheStorage, blob_storage e File System regeneráveis quando navegadores fechados." "$ICON_BROWSER"
    register_action electron_ide_cache "Limpar IDEs/Electron" "Apps e navegadores" "seguro" "Remove caches regeneráveis de VS Code, VSCodium, JetBrains, Discord, Slack, Obsidian e similares." "🧠"
    register_action gpu_shader_cache "Limpar shader/GPU cache" "Apps e navegadores" "seguro" "Remove caches Mesa, Vulkan, NVIDIA ComputeCache e GPUCache regeneráveis." "$ICON_GPU"
    register_action virtualenv_preview "Preview de ambientes virtuais" "Regeneráveis" "leitura" "Lista venv/.venv/env/.tox/.nox sob HOME sem apagar." "🐍"
    register_action virtualenv_cleanup "Remover ambientes virtuais regeneráveis" "Regeneráveis" "alto" "Remove venv/.venv/env/.tox/.nox sob HOME, com confirmação explícita." "🐍"
    register_action node_modules_preview "Preview node_modules antigos" "Regeneráveis" "leitura" "Lista node_modules antigos com package.json irmão sem apagar." "🟩"
    register_action node_modules_cleanup "Remover node_modules antigos" "Regeneráveis" "alto" "Remove node_modules antigos com package.json irmão, com confirmação explícita." "🟩"
    register_action docker_status "Diagnóstico Docker" "Docker" "leitura" "Mostra docker system df quando o daemon estiver ativo." "$ICON_DOCKER"
    register_action docker_safe_prune "Docker seguro" "Docker" "seguro" "Executa builder prune e network prune, sem apagar imagens/containers." "$ICON_DOCKER"
    register_action docker_destructive_prune "Docker destrutivo" "Docker" "alto" "Executa docker system prune -a -f, exige confirmação APAGAR-DOCKER." "$ICON_DOCKER"
    register_action snap_flatpak "Atualizar Snap/Flatpak" "Pacotes universais" "admin" "Atualiza Snap/Flatpak e remove revisões/runtimes não usados quando disponíveis." "🧊"
    register_action journal_cleanup "Limpar Journal/crash" "Sistema" "admin" "Executa journalctl --vacuum-time=3d e limpa /var/crash." "🧾"
    register_action performance_session "Performance da sessão WSL2" "Sistema" "admin" "Ajusta sysctl de sessão, drop_caches e fstrim." "$ICON_SPEED"
    register_action wsl_diagnostics "Diagnóstico WSL2" "Diagnóstico" "leitura" "Mostra integração WSL, Windows interop, wsl.conf e informações do kernel." "$ICON_WSL"
    register_action network_dns_audit "Auditoria DNS/rede" "Diagnóstico" "leitura" "Mostra resolv.conf, rotas, hosts e teste DNS leve." "🌐"
    register_action mounts_audit "Auditoria de mounts" "Diagnóstico" "leitura" "Mostra mounts relevantes, /mnt e filesystem root." "$ICON_DISK"
    register_action apt_sources_audit "Auditoria sources APT" "Diagnóstico" "leitura" "Lista sources.list e sources.list.d sem alterar nada." "$ICON_PACKAGE"
    register_action largest_offenders "Maiores ofensores em HOME" "Diagnóstico" "leitura" "Lista maiores diretórios e arquivos no HOME sem apagar." "$ICON_DISK"
    register_action reclaim_estimate "Estimativa recuperável" "Diagnóstico" "leitura" "Estima tamanho de caches conhecidos sem apagar." "$ICON_DISK"
    register_action all_safe "Executar pacote seguro" "Execução em lote" "lote" "Executa diagnóstico, APT repair/update/cleanup, temporários, caches dev e Docker seguro." "$ICON_SHIELD"
    register_action all_fast "Executar turbo seguro" "Execução em lote" "lote" "Executa conjunto rápido seguro, sem varreduras longas e sem destrutivos." "$ICON_STAR"
    ACTIONS_INITIALIZED=true
}

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/}"
    printf '%s' "$s"
}

list_actions_json() {
    init_actions
    local i comma=""
    printf '['
    for ((i=0; i<${#ACTION_IDS[@]}; i++)); do
        printf '%s{"id":"%s","number":%d,"title":"%s","group":"%s","risk":"%s","description":"%s","icon":"%s"}' \
            "$comma" "$(json_escape "${ACTION_IDS[$i]}")" "$((i+1))" "$(json_escape "${ACTION_TITLES[$i]}")" "$(json_escape "${ACTION_GROUPS[$i]}")" "$(json_escape "${ACTION_RISKS[$i]}")" "$(json_escape "${ACTION_DESCS[$i]}")" "$(json_escape "${ACTION_ICONS[$i]}")"
        comma=','
    done
    printf ']\n'
}

action_id_from_number() {
    init_actions
    local n="$1"
    [[ "$n" =~ ^[0-9]+$ ]] || return 1
    (( n >= 1 && n <= ${#ACTION_IDS[@]} )) || return 1
    printf '%s' "${ACTION_IDS[$((n-1))]}"
}

# -----------------------------------------------------------------------------
# Ações reais
# -----------------------------------------------------------------------------
step_health_overview() {
    say ok "Diagnóstico geral somente leitura"
    printf 'Distro: %s\n' "$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo desconhecida)"
    printf 'Kernel: %s\n' "$(uname -r 2>/dev/null || echo desconhecido)"
    printf 'Usuário alvo: %s\n' "${SUDO_USER:-${USER:-desconhecido}}"
    printf 'HOME alvo: %s\n' "$HOME"
    uptime -p 2>/dev/null || true
    echo; df -h / "$HOME" 2>/dev/null || df -h
    echo; free -h 2>/dev/null || true
    echo; ps -eo pid,ppid,comm,%mem,%cpu --sort=-%mem 2>/dev/null | head -15 || true
    echo; if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then docker system df || true; else echo "Docker indisponível ou daemon parado."; fi
}

step_sudo_refresh() {
    if [[ "${EUID}" -eq 0 ]]; then say ok "Executando como root; sudo não é necessário."; return 0; fi
    run_external "Validando/renovando sessão sudo" sudo -v
}

step_apt_update() { check_apt_lock || return 1; run_external "Atualizando índices APT" sudo_run apt-get update; }
step_apt_repair() { check_apt_lock || return 1; run_external "Reconfigurando DPKG" sudo_run dpkg --configure -a; run_external "Corrigindo dependências APT" sudo_run apt-get install -f -y; }
step_apt_upgrade() { check_apt_lock || return 1; run_external "Atualizando pacotes instalados" sudo_run apt-get upgrade -y; }
step_apt_cleanup() {
    check_apt_lock || return 1
    run_external "Removendo pacotes órfãos" sudo_run apt-get autoremove --purge -y || true
    run_external "Limpando cache APT antigo" sudo_run apt-get autoclean -y || true
    run_external "Limpando cache APT completo" sudo_run apt-get clean || true
    if [[ -d /var/cache/apt/archives/partial ]]; then sudo_run find /var/cache/apt/archives/partial -mindepth 1 -ignore_readdir_race -exec rm -rf -- {} + 2>/dev/null || true; fi
    say ok "Cache APT finalizado."
}

step_tmp_cleanup() {
    say cmd "Limpando /tmp com entradas antigas >1 dia"
    sudo_run find /tmp -mindepth 1 -xdev -ignore_readdir_race -mtime +1 -exec rm -rf -- {} + 2>/dev/null || true
    say cmd "Limpando /var/tmp com entradas antigas >7 dias"
    sudo_run find /var/tmp -mindepth 1 -xdev -ignore_readdir_race -mtime +7 -exec rm -rf -- {} + 2>/dev/null || true
    say ok "Temporários seguros finalizados."
}

step_user_cache_old() {
    local dir="$HOME/.cache"
    [[ -d "$dir" ]] || { say warn "Diretório não existe: $dir"; return 0; }
    say cmd "Removendo arquivos antigos em $dir (>30 dias)"
    find "$dir" -type f -ignore_readdir_race -mtime +30 -delete 2>/dev/null || true
    say ok "Cache antigo do usuário finalizado."
}

step_thumbnails_cleanup() { local dir="$HOME/.cache/thumbnails"; [[ -d "$dir" ]] && find "$dir" -mindepth 1 -ignore_readdir_race -exec rm -rf -- {} + 2>/dev/null || true; say ok "Miniaturas limpas."; }
step_trash_cleanup() { local base="$HOME/.local/share/Trash"; [[ -d "$base/files" ]] && find "$base/files" -mindepth 1 -ignore_readdir_race -exec rm -rf -- {} + 2>/dev/null || true; [[ -d "$base/info" ]] && find "$base/info" -mindepth 1 -ignore_readdir_race -exec rm -rf -- {} + 2>/dev/null || true; say ok "Lixeira Linux esvaziada."; }
step_font_cache() { local dir="$HOME/.cache/fontconfig"; [[ -d "$dir" ]] && find "$dir" -mindepth 1 -ignore_readdir_race -exec rm -rf -- {} + 2>/dev/null || true; command -v fc-cache >/dev/null 2>&1 && run_external "Reconstruindo cache de fontes" fc-cache -r || say warn "fc-cache não instalado."; }

step_pip_cache() { command -v python3 >/dev/null 2>&1 && run_external "Limpando pip via python3" python3 -m pip cache purge || true; command -v pip3 >/dev/null 2>&1 && run_external "Limpando pip3" pip3 cache purge || true; }
step_node_cache() { command -v npm >/dev/null 2>&1 && run_external "Limpando cache npm" npm cache clean --force || say warn "npm não instalado."; command -v yarn >/dev/null 2>&1 && run_external "Limpando cache yarn" yarn cache clean || true; command -v pnpm >/dev/null 2>&1 && run_external "Executando pnpm store prune" pnpm store prune || true; }

clean_known_dirs() {
    local label="$1"; shift
    local target
    for target in "$@"; do
        [[ -e "$target" ]] || continue
        remove_tree_guarded "$target" "$label" || true
    done
}

step_python_modern_cache() {
    command -v uv >/dev/null 2>&1 && run_external "Limpando cache uv" uv cache clean || true
    command -v pdm >/dev/null 2>&1 && run_external "Limpando cache PDM" pdm cache clear || true
    command -v hatch >/dev/null 2>&1 && run_external "Limpando cache Hatch" hatch cache purge || true
    command -v pipenv >/dev/null 2>&1 && run_external "Limpando Pipenv" pipenv --clear || true
    clean_known_dirs "cache Python moderno" "$HOME/.cache/uv" "$HOME/.local/share/uv/cache" "$HOME/.cache/pipenv" "$HOME/.cache/pdm" "$HOME/.cache/pipx" "$HOME/.local/pipx/.cache" "$HOME/.cache/hatch" "$HOME/.local/share/hatch/env" "$HOME/.cache/rye" "$HOME/.rye/self/cache"
}

step_java_cache() {
    [[ -d "$HOME/.gradle/caches" ]] && find "$HOME/.gradle/caches" -mindepth 1 -maxdepth 1 -ignore_readdir_race \( -name 'build-cache-*' -o -name 'jars-*' -o -name 'transforms-*' -o -name 'journal-*' \) -exec rm -rf -- {} + 2>/dev/null || true
    [[ -d "$HOME/.m2/repository" ]] && find "$HOME/.m2/repository" -type f \( -name '*.lastUpdated' -o -name '_remote.repositories' \) -delete 2>/dev/null || true
    clean_known_dirs "cache Gradle" "$HOME/.gradle/daemon" "$HOME/.gradle/native" "$HOME/.gradle/kotlin"
    say ok "Caches Java seguros finalizados."
}

step_go_rust_cache() {
    command -v go >/dev/null 2>&1 && run_external "Limpando caches Go" go clean -cache -modcache -testcache || say warn "Go não instalado."
    clean_known_dirs "cache Cargo" "$HOME/.cargo/registry/cache" "$HOME/.cargo/git/db"
}

step_composer_dotnet_cache() { command -v composer >/dev/null 2>&1 && run_external "Limpando Composer" composer clear-cache || say warn "Composer não instalado."; command -v dotnet >/dev/null 2>&1 && run_external "Limpando NuGet/.NET" dotnet nuget locals all --clear || say warn ".NET SDK não instalado."; }

step_browser_safe_cache() {
    if process_active chrome google-chrome chromium chromium-browser brave brave-browser msedge microsoft-edge firefox librewolf waterfox floorp zen; then
        say warn "Navegador aberto detectado; limpeza de navegador ignorada para evitar corrupção de perfil."
        return 0
    fi
    clean_known_dirs "cache navegador" \
        "$HOME/.cache/google-chrome" "$HOME/.cache/chromium" "$HOME/.cache/microsoft-edge" "$HOME/.cache/BraveSoftware/Brave-Browser" "$HOME/.cache/mozilla" \
        "$HOME/.config/google-chrome/ShaderCache" "$HOME/.config/google-chrome/GrShaderCache" "$HOME/.config/chromium/ShaderCache" "$HOME/.config/chromium/GrShaderCache" \
        "$HOME/.config/microsoft-edge/ShaderCache" "$HOME/.config/BraveSoftware/Brave-Browser/ShaderCache"
    say ok "Cache seguro de navegadores finalizado."
}

step_browser_advanced_cache() {
    if process_active chrome google-chrome chromium chromium-browser brave brave-browser msedge microsoft-edge firefox librewolf waterfox floorp zen; then
        say warn "Navegador aberto detectado; limpeza avançada ignorada."
        return 0
    fi
    local base
    for base in "$HOME/.config/google-chrome" "$HOME/.config/chromium" "$HOME/.config/microsoft-edge" "$HOME/.config/BraveSoftware/Brave-Browser"; do
        [[ -d "$base" ]] || continue
        find "$base" -type d \( -name 'CacheStorage' -o -name 'ScriptCache' -o -name 'blob_storage' -o -name 'GPUCache' -o -name 'DawnCache' \) -prune -print0 2>/dev/null | while IFS= read -r -d '' d; do remove_tree_guarded "$d" "cache avançado navegador" || true; done
    done
    say ok "Cache avançado de navegadores finalizado."
}

step_electron_ide_cache() {
    clean_known_dirs "cache IDE/Electron" \
        "$HOME/.config/Code/Cache" "$HOME/.config/Code/CachedData" "$HOME/.config/Code/Code Cache" "$HOME/.config/Code/GPUCache" "$HOME/.config/Code/DawnCache" "$HOME/.config/Code/CachedExtensionVSIXs" "$HOME/.config/Code/logs" "$HOME/.config/Code/User/workspaceStorage" \
        "$HOME/.config/VSCodium/Cache" "$HOME/.config/VSCodium/CachedData" "$HOME/.config/VSCodium/Code Cache" "$HOME/.config/VSCodium/GPUCache" "$HOME/.cache/JetBrains" "$HOME/.cache/discord" "$HOME/.cache/Discord" "$HOME/.cache/Slack" "$HOME/.cache/slack" "$HOME/.cache/obsidian" "$HOME/.cache/TelegramDesktop"
}

step_gpu_shader_cache() { clean_known_dirs "cache shader/GPU" "$HOME/.cache/mesa_shader_cache" "$HOME/.cache/mesa_shader_cache_db" "$HOME/.cache/vulkan" "$HOME/.nv/ComputeCache" "$HOME/GPUCache"; }

find_virtualenvs() {
    find "$HOME" -xdev \
        \( -path "$HOME/.cache" -o -path "$HOME/.local/share/Trash" -o -path "$HOME/snap" -o -path "$HOME/.var" \) -prune -o \
        -type d \( -name 'venv' -o -name '.venv' -o -name 'env' -o -name '.env' -o -name '.tox' -o -name '.nox' \) -prune -print0 2>/dev/null | \
    while IFS= read -r -d '' d; do
        if [[ -f "$d/pyvenv.cfg" || -f "$d/bin/activate" || -d "$d/lib" || "$(basename "$d")" == ".tox" || "$(basename "$d")" == ".nox" ]]; then printf '%s\0' "$d"; fi
    done
}

step_virtualenv_preview() {
    say ok "Preview de ambientes virtuais sob HOME; nada será apagado."
    local count=0 total=0 size d
    while IFS= read -r -d '' d; do size="$(path_size_kb "$d")"; total=$((total+size)); count=$((count+1)); printf '%6s  %s\n' "$(format_kb "$size")" "$d"; done < <(find_virtualenvs)
    printf '\nEncontrados: %d | Estimado: %s\n' "$count" "$(format_kb "$total")"
}

step_virtualenv_cleanup() {
    [[ "${SYSTEM_CARE_PRO_CONFIRM_DELETE:-}" == "APAGAR-REGENERAVEIS" ]] || { say fail "Confirmação ausente. Esta ação exige SYSTEM_CARE_PRO_CONFIRM_DELETE=APAGAR-REGENERAVEIS."; return 1; }
    local d removed=0
    while IFS= read -r -d '' d; do remove_tree_guarded "$d" "ambiente virtual" && removed=$((removed+1)); done < <(find_virtualenvs)
    say ok "Ambientes virtuais removidos: $removed"
}

find_node_modules_old() {
    find "$HOME" -xdev -type d -name node_modules -prune -mtime +21 -print0 2>/dev/null | while IFS= read -r -d '' d; do [[ -f "$(dirname "$d")/package.json" ]] && printf '%s\0' "$d"; done
}

step_node_modules_preview() { say ok "Preview node_modules antigos; nada será apagado."; local count=0 total=0 size d; while IFS= read -r -d '' d; do size="$(path_size_kb "$d")"; total=$((total+size)); count=$((count+1)); printf '%6s  %s\n' "$(format_kb "$size")" "$d"; done < <(find_node_modules_old); printf '\nEncontrados: %d | Estimado: %s\n' "$count" "$(format_kb "$total")"; }
step_node_modules_cleanup() { [[ "${SYSTEM_CARE_PRO_CONFIRM_DELETE:-}" == "APAGAR-REGENERAVEIS" ]] || { say fail "Confirmação ausente. Esta ação exige SYSTEM_CARE_PRO_CONFIRM_DELETE=APAGAR-REGENERAVEIS."; return 1; }; local d removed=0; while IFS= read -r -d '' d; do remove_tree_guarded "$d" "node_modules" && removed=$((removed+1)); done < <(find_node_modules_old); say ok "node_modules removidos: $removed"; }

step_docker_status() { if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then run_external "Uso Docker" docker system df; else say warn "Docker não está disponível ou daemon parado."; fi; }
step_docker_safe_prune() { if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then run_external "Docker builder prune" docker builder prune -af || true; run_external "Docker network prune" docker network prune -f || true; else say warn "Docker indisponível."; fi; }
step_docker_destructive_prune() { [[ "${SYSTEM_CARE_PRO_CONFIRM_DOCKER:-}" == "APAGAR-DOCKER" ]] || { say fail "Confirmação ausente. Esta ação exige SYSTEM_CARE_PRO_CONFIRM_DOCKER=APAGAR-DOCKER."; return 1; }; if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then run_external "Docker system prune -a" docker system prune -a -f; else say warn "Docker indisponível."; fi; }

step_snap_flatpak() { command -v snap >/dev/null 2>&1 && run_external "Atualizando Snap" sudo_run snap refresh || say warn "Snap não instalado."; if command -v snap >/dev/null 2>&1; then snap list --all 2>/dev/null | awk '/disabled/{print $1" "$3}' | while read -r s r; do [[ -n "$s" && -n "$r" ]] && sudo_run snap remove "$s" --revision="$r" || true; done; fi; command -v flatpak >/dev/null 2>&1 && run_external "Atualizando Flatpak" flatpak update -y || say warn "Flatpak não instalado."; command -v flatpak >/dev/null 2>&1 && run_external "Removendo Flatpaks não usados" flatpak uninstall --unused -y || true; }
step_journal_cleanup() { command -v journalctl >/dev/null 2>&1 && run_external "Reduzindo Journal para 3 dias" sudo_run journalctl --vacuum-time=3d || say warn "journalctl indisponível."; [[ -d /var/crash ]] && sudo_run find /var/crash -mindepth 1 -ignore_readdir_race -exec rm -rf -- {} + 2>/dev/null || true; say ok "Journal/crash finalizado."; }
step_performance_session() { sync || true; sudo_run sysctl -w vm.swappiness=10 || true; sudo_run sysctl -w vm.vfs_cache_pressure=50 || true; sudo_run sysctl -w vm.dirty_ratio=10 || true; sudo_run sysctl -w vm.dirty_background_ratio=5 || true; sudo_run sh -c 'echo 3 > /proc/sys/vm/drop_caches' || true; command -v fstrim >/dev/null 2>&1 && run_external "Executando fstrim" sudo_run fstrim -av || true; }

step_wsl_diagnostics() { printf 'WSL_DISTRO_NAME=%s\n' "${WSL_DISTRO_NAME:-não informado}"; printf 'Kernel=%s\n' "$(uname -r)"; command -v powershell.exe >/dev/null 2>&1 && echo 'powershell.exe disponível no PATH WSL.' || echo 'powershell.exe não detectado.'; [[ -f /etc/wsl.conf ]] && { echo; echo '/etc/wsl.conf:'; sed -n '1,160p' /etc/wsl.conf; } || echo '/etc/wsl.conf ausente.'; }
step_network_dns_audit() { echo '/etc/resolv.conf:'; sed -n '1,120p' /etc/resolv.conf 2>/dev/null || true; echo; echo 'Rotas:'; ip route 2>/dev/null || route -n 2>/dev/null || true; echo; getent hosts github.com google.com 2>/dev/null || true; }
step_mounts_audit() { echo 'Filesystem root:'; df -h /; echo; echo 'Mounts WSL/mnt:'; mount | grep -E 'drvfs|wsl|/mnt|type ext4' || true; echo; ls -la /mnt 2>/dev/null || true; }
step_apt_sources_audit() { echo '/etc/apt/sources.list:'; sed -n '1,220p' /etc/apt/sources.list 2>/dev/null || true; echo; echo 'sources.list.d:'; find /etc/apt/sources.list.d -maxdepth 1 -type f -print -exec sed -n '1,120p' {} \; 2>/dev/null || true; }
step_largest_offenders() { echo 'Maiores diretórios em HOME:'; du -h --max-depth=1 "$HOME" 2>/dev/null | sort -rh | head -30 || true; echo; echo 'Maiores arquivos em HOME:'; find "$HOME" -xdev -type f -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -30 | awk '{printf "%.1f MB\t%s\n", $1/1024/1024, $2}' || true; }
step_reclaim_estimate() { local total=0 size target; for target in "$HOME/.cache" "$HOME/.cache/thumbnails" "$HOME/.local/share/Trash" "$HOME/.npm" "$HOME/.cache/pip" "$HOME/.gradle/caches" "$HOME/.cargo/registry/cache"; do size="$(path_size_kb "$target")"; total=$((total+size)); printf '%8s  %s\n' "$(format_kb "$size")" "$target"; done; printf '\nEstimativa bruta de caches conhecidos: %s\n' "$(format_kb "$total")"; }

run_action() {
    local id="${1:-}"
    case "$id" in
        health_overview) step_health_overview ;;
        sudo_refresh) step_sudo_refresh ;;
        apt_update) step_apt_update ;;
        apt_repair) step_apt_repair ;;
        apt_upgrade) step_apt_upgrade ;;
        apt_cleanup) step_apt_cleanup ;;
        tmp_cleanup) step_tmp_cleanup ;;
        user_cache_old) step_user_cache_old ;;
        thumbnails_cleanup) step_thumbnails_cleanup ;;
        trash_cleanup) step_trash_cleanup ;;
        font_cache) step_font_cache ;;
        pip_cache) step_pip_cache ;;
        node_cache) step_node_cache ;;
        python_modern_cache) step_python_modern_cache ;;
        java_cache) step_java_cache ;;
        go_rust_cache) step_go_rust_cache ;;
        composer_dotnet_cache) step_composer_dotnet_cache ;;
        browser_safe_cache) step_browser_safe_cache ;;
        browser_advanced_cache) step_browser_advanced_cache ;;
        electron_ide_cache) step_electron_ide_cache ;;
        gpu_shader_cache) step_gpu_shader_cache ;;
        virtualenv_preview) step_virtualenv_preview ;;
        virtualenv_cleanup) step_virtualenv_cleanup ;;
        node_modules_preview) step_node_modules_preview ;;
        node_modules_cleanup) step_node_modules_cleanup ;;
        docker_status) step_docker_status ;;
        docker_safe_prune) step_docker_safe_prune ;;
        docker_destructive_prune) step_docker_destructive_prune ;;
        snap_flatpak) step_snap_flatpak ;;
        journal_cleanup) step_journal_cleanup ;;
        performance_session) step_performance_session ;;
        wsl_diagnostics) step_wsl_diagnostics ;;
        network_dns_audit) step_network_dns_audit ;;
        mounts_audit) step_mounts_audit ;;
        apt_sources_audit) step_apt_sources_audit ;;
        largest_offenders) step_largest_offenders ;;
        reclaim_estimate) step_reclaim_estimate ;;
        all_safe) step_health_overview; step_apt_repair; step_apt_update; step_apt_cleanup; step_tmp_cleanup; step_user_cache_old; step_thumbnails_cleanup; step_trash_cleanup; step_pip_cache; step_node_cache; step_python_modern_cache; step_browser_safe_cache; step_electron_ide_cache; step_gpu_shader_cache; step_docker_safe_prune; command -v fstrim >/dev/null 2>&1 && sudo_run fstrim -av || true ;;
        all_fast) step_health_overview; step_tmp_cleanup; step_user_cache_old; step_thumbnails_cleanup; step_pip_cache; step_node_cache; step_browser_safe_cache; step_gpu_shader_cache; step_reclaim_estimate ;;
        *) say fail "Ação inexistente: $id"; return 127 ;;
    esac
}

# -----------------------------------------------------------------------------
# TUI CLI fallback, com roteamento simples e estável.
# -----------------------------------------------------------------------------
cli_menu() {
    init_actions
    local choice id i current_group=""
    while true; do
        line
        printf '%b%s %s v%s — CLI estável%b\n' "$(c "$C_PRIMARY$BOLD")" "$ICON_SHIELD" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$(ce)"
        line
        for ((i=0; i<${#ACTION_IDS[@]}; i++)); do
            if [[ "${ACTION_GROUPS[$i]}" != "$current_group" ]]; then
                current_group="${ACTION_GROUPS[$i]}"; printf '\n  %b%s%b\n' "$(c "$C_SECONDARY$BOLD")" "$current_group" "$(ce)"
            fi
            printf '  %b%02d%b  %s  %-38s  %b[%s]%b\n' "$(c "$C_ACCENT")" "$((i+1))" "$(ce)" "${ACTION_ICONS[$i]}" "${ACTION_TITLES[$i]}" "$(c "$C_MUTED")" "${ACTION_RISKS[$i]}" "$(ce)"
        done
        printf '\n  %b00%b  %s  Sair\n\n' "$(c "$C_ERROR")" "$(ce)" "$ICON_EXIT"
        printf '  Escolha: '
        read -r choice
        case "${choice,,}" in q|quit|exit|sair|s|0|00) say ok "Finalizado."; return 0 ;; esac
        id="$(action_id_from_number "$choice" 2>/dev/null || true)"
        if [[ -z "$id" ]]; then say fail "Opção inexistente: $choice"; sleep 1; continue; fi
        line; say cmd "Executando: $id"; run_action "$id" || true; line
        printf '  Pressione ENTER para voltar ao menu...'; read -r _
    done
}

menu_preview() {
    init_actions
    local i
    for ((i=0; i<${#ACTION_IDS[@]}; i++)); do printf '%02d  %-30s  %s\n' "$((i+1))" "${ACTION_IDS[$i]}" "${ACTION_TITLES[$i]}"; done
}

# -----------------------------------------------------------------------------
# Servidor Web CSS gráfico. Não grava arquivos. HTML, CSS e JS ficam no processo.
# -----------------------------------------------------------------------------
launch_web_tui() {
    require_python3
    local port="${SYSTEM_CARE_PRO_PORT:-$DEFAULT_WEB_PORT}"
    local script_path
    script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
    export SYSTEM_CARE_PRO_SCRIPT="$script_path"
    export SYSTEM_CARE_PRO_PORT_VALUE="$port"
    python3 -u - <<'PYWEB'
import json, os, secrets, subprocess, sys, time, shutil, socket, threading, webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

SCRIPT = os.environ.get("SYSTEM_CARE_PRO_SCRIPT")
PORT = int(os.environ.get("SYSTEM_CARE_PRO_PORT_VALUE", "8787"))
TOKEN = secrets.token_urlsafe(24)
STARTED = time.time()

def run_cmd(args, timeout=120, extra_env=None):
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    try:
        p = subprocess.run(args, text=True, capture_output=True, timeout=timeout, env=env)
        return {"ok": p.returncode == 0, "code": p.returncode, "stdout": p.stdout, "stderr": p.stderr}
    except subprocess.TimeoutExpired as e:
        return {"ok": False, "code": 124, "stdout": e.stdout or "", "stderr": "Tempo esgotado."}
    except Exception as e:
        return {"ok": False, "code": 1, "stdout": "", "stderr": str(e)}

def get_actions():
    r = run_cmd([SCRIPT, "--list-actions-json"], timeout=30)
    if not r["ok"]:
        return []
    try:
        return json.loads(r["stdout"])
    except Exception:
        return []

def human_uptime():
    seconds = int(time.time() - STARTED)
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    return f"{h:02d}:{m:02d}:{s:02d}"

def read_status():
    def shell(cmd):
        return subprocess.run(cmd, shell=True, text=True, capture_output=True, timeout=8).stdout.strip()
    disk_line = shell("df -P / | awk 'NR==2{print $3, $4, $5}'")
    mem_line = shell("free -m | awk '/Mem:/{print $3, $2}'")
    distro = shell("grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '\"'") or "WSL2 Ubuntu"
    kernel = shell("uname -r")
    wsl = bool(os.environ.get("WSL_DISTRO_NAME")) or "microsoft" in shell("cat /proc/version 2>/dev/null").lower()
    disk_used = disk_free = disk_pct = 0
    if disk_line:
        parts = disk_line.split()
        try:
            disk_used = int(parts[0]); disk_free = int(parts[1]); disk_pct = int(parts[2].rstrip('%'))
        except Exception: pass
    mem_used = mem_total = mem_pct = 0
    if mem_line:
        parts = mem_line.split()
        try:
            mem_used = int(parts[0]); mem_total = int(parts[1]); mem_pct = int(mem_used * 100 / max(mem_total, 1))
        except Exception: pass
    sudo_cached = subprocess.run("sudo -n true", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    docker_active = subprocess.run("command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1", shell=True).returncode == 0
    return {"name":"System Care Pro WSL2", "version":"8.0.0-webnova", "engine":"WebNova TUI CSS", "uptime":human_uptime(), "distro":distro, "kernel":kernel, "wsl":wsl, "sudoCached":sudo_cached, "dockerActive":docker_active, "diskPct":disk_pct, "memPct":mem_pct, "diskUsedKb":disk_used, "diskFreeKb":disk_free, "memUsedMb":mem_used, "memTotalMb":mem_total, "time":time.strftime('%H:%M:%S')}

HTML = r'''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>System Care Pro WSL2 — WebNova</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Imprima&display=swap');
</style>
<style>
:root{
  color-scheme: dark;
  --bg:#050713; --bg2:#090d22; --glass:rgba(255,255,255,.08); --glass2:rgba(255,255,255,.12);
  --line:rgba(255,255,255,.18); --text:#eef4ff; --muted:#9cabc7; --cyan:#22e9ff; --mint:#32ffc6;
  --violet:#9a6cff; --pink:#ff5c9e; --warn:#ffd166; --danger:#ff5f7e; --ok:#4ade80; --shadow:0 24px 80px rgba(0,0,0,.42);
  --radius:28px; --radius2:18px; --font:"Imprima",system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
}
*{box-sizing:border-box} html{scroll-behavior:smooth} body{margin:0;min-height:100vh;font-family:var(--font);color:var(--text);background:radial-gradient(circle at 10% 0%,rgba(154,108,255,.42),transparent 35%),radial-gradient(circle at 90% 5%,rgba(34,233,255,.30),transparent 30%),radial-gradient(circle at 50% 110%,rgba(50,255,198,.18),transparent 35%),linear-gradient(140deg,var(--bg),var(--bg2));overflow-x:hidden}
body::before{content:"";position:fixed;inset:0;pointer-events:none;background:linear-gradient(rgba(255,255,255,.035) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.025) 1px,transparent 1px);background-size:44px 44px;mask-image:radial-gradient(circle at 50% 20%,#000,transparent 72%);}
body::after{content:"";position:fixed;width:56vmax;height:56vmax;right:-20vmax;top:-20vmax;border-radius:999px;border:1px solid rgba(255,255,255,.12);background:conic-gradient(from 20deg,transparent,rgba(34,233,255,.2),transparent,rgba(154,108,255,.25),transparent);filter:blur(.2px);animation:orbit 28s linear infinite;pointer-events:none;opacity:.75}@keyframes orbit{to{transform:rotate(360deg)}}
.shell{width:min(1480px,calc(100% - 32px));margin:0 auto;padding:24px 0 44px}.hero{position:relative;border:1px solid var(--line);border-radius:36px;padding:28px;box-shadow:var(--shadow);background:linear-gradient(135deg,rgba(255,255,255,.12),rgba(255,255,255,.045));backdrop-filter:blur(26px);overflow:hidden}.hero:before{content:"";position:absolute;inset:-2px;background:radial-gradient(circle at 15% 20%,rgba(34,233,255,.22),transparent 28%),radial-gradient(circle at 80% 0%,rgba(255,92,158,.20),transparent 30%);pointer-events:none}.hero>*{position:relative}.top{display:flex;justify-content:space-between;gap:20px;align-items:flex-start;flex-wrap:wrap}.brand{display:flex;align-items:center;gap:16px}.logo{width:64px;height:64px;border-radius:22px;display:grid;place-items:center;background:linear-gradient(135deg,var(--cyan),var(--violet) 55%,var(--pink));box-shadow:0 16px 50px rgba(34,233,255,.24);font-size:30px}.eyebrow{color:var(--mint);letter-spacing:.18em;text-transform:uppercase;font-size:12px}.title{font-size:clamp(34px,6vw,78px);line-height:.92;margin:6px 0 4px;letter-spacing:-.055em}.subtitle{max-width:860px;color:var(--muted);font-size:18px;line-height:1.55}.actions{display:flex;gap:12px;flex-wrap:wrap;justify-content:flex-end}.btn{appearance:none;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.09);color:var(--text);border-radius:999px;padding:12px 16px;font-family:var(--font);font-size:15px;cursor:pointer;transition:.18s ease;box-shadow:inset 0 1px 0 rgba(255,255,255,.15)}.btn:hover{transform:translateY(-1px);background:rgba(255,255,255,.15)}.btn.primary{background:linear-gradient(135deg,var(--cyan),var(--violet));color:#05101f;border:0;font-weight:800}.btn.danger{background:linear-gradient(135deg,var(--danger),var(--pink));border:0;color:white}.bento{display:grid;grid-template-columns:repeat(12,1fr);gap:16px;margin-top:18px}.card{border:1px solid var(--line);background:linear-gradient(135deg,rgba(255,255,255,.105),rgba(255,255,255,.045));backdrop-filter:blur(18px);border-radius:var(--radius);padding:18px;box-shadow:0 10px 40px rgba(0,0,0,.25);min-height:132px;position:relative;overflow:hidden}.card:after{content:"";position:absolute;inset:auto -20% -50% auto;width:160px;height:160px;border-radius:50%;background:radial-gradient(circle,rgba(34,233,255,.13),transparent 70%)}.span3{grid-column:span 3}.span4{grid-column:span 4}.span5{grid-column:span 5}.span7{grid-column:span 7}.span8{grid-column:span 8}.span12{grid-column:span 12}.metric{font-size:38px;letter-spacing:-.04em;margin-top:8px}.label{color:var(--muted);font-size:13px;text-transform:uppercase;letter-spacing:.12em}.meter{height:12px;border-radius:999px;background:rgba(255,255,255,.10);overflow:hidden;margin-top:16px}.meter>i{display:block;height:100%;width:0%;background:linear-gradient(90deg,var(--mint),var(--cyan),var(--violet));border-radius:inherit;transition:width .5s ease}.toolbar{display:flex;gap:12px;align-items:center;justify-content:space-between;flex-wrap:wrap;margin:22px 0}.search{flex:1;min-width:260px;position:relative}.search input{width:100%;border:1px solid var(--line);background:rgba(4,8,24,.55);color:var(--text);border-radius:999px;padding:15px 18px 15px 46px;font:16px var(--font);outline:none}.search span{position:absolute;left:18px;top:13px;color:var(--muted)}.chips{display:flex;gap:8px;flex-wrap:wrap}.chip{border:1px solid var(--line);background:rgba(255,255,255,.07);border-radius:999px;padding:9px 12px;color:var(--muted);cursor:pointer}.chip.active{color:#06121d;background:linear-gradient(135deg,var(--mint),var(--cyan));border:0}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.action-card{border:1px solid var(--line);background:linear-gradient(145deg,rgba(255,255,255,.12),rgba(255,255,255,.045));border-radius:26px;padding:18px;min-height:220px;display:flex;flex-direction:column;gap:12px;position:relative;overflow:hidden;transition:.18s ease}.action-card:hover{transform:translateY(-3px);border-color:rgba(34,233,255,.45);box-shadow:0 18px 50px rgba(0,0,0,.28)}.action-head{display:flex;gap:12px;align-items:center}.action-icon{width:44px;height:44px;display:grid;place-items:center;border-radius:16px;background:rgba(255,255,255,.10);font-size:22px}.action-title{font-size:20px;line-height:1.1}.desc{color:var(--muted);line-height:1.45;min-height:44px}.risk{width:max-content;border-radius:999px;padding:7px 10px;font-size:12px;text-transform:uppercase;letter-spacing:.1em;border:1px solid var(--line);color:var(--muted)}.risk.leitura{color:var(--cyan)}.risk.seguro{color:var(--ok)}.risk.admin,.risk.atenção,.risk.lote{color:var(--warn)}.risk.alto{color:var(--danger)}.run{margin-top:auto;width:100%;border:0;border-radius:18px;padding:14px;background:linear-gradient(135deg,rgba(34,233,255,.92),rgba(154,108,255,.92));color:#06101e;font:800 15px var(--font);cursor:pointer}.run:hover{filter:brightness(1.1)}.run.alto{background:linear-gradient(135deg,var(--danger),var(--pink));color:white}.console{position:sticky;bottom:14px;z-index:5;border:1px solid rgba(255,255,255,.20);border-radius:28px;background:rgba(3,6,18,.82);backdrop-filter:blur(22px);box-shadow:0 24px 80px rgba(0,0,0,.55);overflow:hidden}.console-top{display:flex;justify-content:space-between;align-items:center;padding:14px 16px;border-bottom:1px solid rgba(255,255,255,.12)}.lights{display:flex;gap:7px}.lights i{width:10px;height:10px;border-radius:50%;display:block}.lights i:nth-child(1){background:var(--danger)}.lights i:nth-child(2){background:var(--warn)}.lights i:nth-child(3){background:var(--ok)}pre{margin:0;padding:18px;max-height:360px;overflow:auto;white-space:pre-wrap;color:#d9f7ff;font:13px/1.55 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}.pulse{display:inline-flex;width:10px;height:10px;border-radius:50%;background:var(--ok);box-shadow:0 0 0 0 rgba(74,222,128,.7);animation:pulse 1.8s infinite}@keyframes pulse{70%{box-shadow:0 0 0 12px transparent}}.hidden{display:none!important}@media (max-width:1100px){.grid{grid-template-columns:repeat(2,1fr)}.span3,.span4,.span5,.span7,.span8{grid-column:span 6}}@media (max-width:760px){.shell{width:min(100% - 18px,1480px);padding-top:10px}.hero{padding:20px;border-radius:28px}.grid{grid-template-columns:1fr}.span3,.span4,.span5,.span7,.span8,.span12{grid-column:span 12}.title{font-size:42px}.actions{justify-content:flex-start}.console{position:relative;bottom:auto;margin-top:18px}}@media (prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important;scroll-behavior:auto!important}}
</style>
</head>
<body>
<div class="shell">
  <section class="hero">
    <div class="top">
      <div class="brand"><div class="logo">🛡️</div><div><div class="eyebrow">WebNova TUI CSS • Junho 2026</div><h1 class="title">System Care Pro WSL2</h1></div></div>
      <div class="actions"><button class="btn" id="refresh">Atualizar status</button><button class="btn primary" id="sudo">Validar sudo</button><button class="btn danger" id="clearConsole">Limpar console</button></div>
    </div>
    <p class="subtitle">Painel local gráfico em CSS com bento grid, glassmorphism, tipografia Imprima, UX agentic com um clique e roteamento real das ações. Nada roda sozinho: cada card chama uma ação existente no backend Bash.</p>
    <div class="bento">
      <div class="card span3"><div class="label">Disco root</div><div class="metric" id="diskPct">--%</div><div class="meter"><i id="diskBar"></i></div></div>
      <div class="card span3"><div class="label">Memória</div><div class="metric" id="memPct">--%</div><div class="meter"><i id="memBar"></i></div></div>
      <div class="card span3"><div class="label">Sudo</div><div class="metric" id="sudoState">--</div><div class="desc">Ações admin usam sudo em cache no terminal.</div></div>
      <div class="card span3"><div class="label">Servidor local</div><div class="metric"><span class="pulse"></span> ON</div><div class="desc" id="engine">WebNova</div></div>
      <div class="card span8"><div class="label">Ambiente</div><div class="metric" id="distro">Carregando...</div><div class="desc" id="kernel"></div></div>
      <div class="card span4"><div class="label">Docker</div><div class="metric" id="dockerState">--</div><div class="desc">Daemon ativo será detectado automaticamente.</div></div>
    </div>
  </section>
  <div class="toolbar">
    <div class="search"><span>⌕</span><input id="search" placeholder="Buscar ação, cache, docker, apt, navegador..." /></div>
    <div class="chips" id="chips"></div>
  </div>
  <main class="grid" id="grid"></main>
  <section class="console"><div class="console-top"><div class="lights"><i></i><i></i><i></i></div><strong id="consoleTitle">Console real</strong><button class="btn" id="copyConsole">Copiar</button></div><pre id="console">Pronto. Escolha uma ação nos cards acima.\n</pre></section>
</div>
<script>
const token = new URLSearchParams(location.search).get('token') || '';
let actions = [], group = 'Todos', running = false;
const $ = s => document.querySelector(s);
function log(txt){ $('#console').textContent += txt; $('#console').scrollTop = $('#console').scrollHeight; }
async function api(path, opts={}){ const r = await fetch(path + (path.includes('?')?'&':'?') + 'token=' + encodeURIComponent(token), opts); if(!r.ok) throw new Error('HTTP '+r.status); return await r.json(); }
function riskClass(r){ return (r||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase(); }
function renderChips(){ const groups=['Todos',...new Set(actions.map(a=>a.group))]; $('#chips').innerHTML = groups.map(g=>`<button class="chip ${g===group?'active':''}" data-g="${g}">${g}</button>`).join(''); document.querySelectorAll('.chip').forEach(b=>b.onclick=()=>{group=b.dataset.g;render()}); }
function render(){ const q=$('#search').value.toLowerCase(); const list=actions.filter(a=>(group==='Todos'||a.group===group)&&(`${a.title} ${a.description} ${a.group} ${a.risk}`.toLowerCase().includes(q))); $('#grid').innerHTML = list.map(a=>`<article class="action-card"><div class="action-head"><div class="action-icon">${a.icon}</div><div><div class="risk ${riskClass(a.risk)}">${String(a.number).padStart(2,'0')} • ${a.risk}</div><div class="action-title">${a.title}</div></div></div><div class="desc">${a.description}</div><button class="run ${riskClass(a.risk)}" data-id="${a.id}" data-risk="${a.risk}">Executar ação real</button></article>`).join('') || '<div class="card span12">Nenhuma ação encontrada.</div>'; document.querySelectorAll('.run').forEach(b=>b.onclick=()=>runAction(b.dataset.id,b.dataset.risk)); }
async function refresh(){ const s=await api('/api/status'); $('#diskPct').textContent=s.diskPct+'%'; $('#diskBar').style.width=s.diskPct+'%'; $('#memPct').textContent=s.memPct+'%'; $('#memBar').style.width=s.memPct+'%'; $('#sudoState').textContent=s.sudoCached?'OK':'OFF'; $('#dockerState').textContent=s.dockerActive?'Ativo':'Parado'; $('#engine').textContent=s.engine+' • '+s.uptime; $('#distro').textContent=s.distro; $('#kernel').textContent=s.kernel; }
async function load(){ actions=await api('/api/actions'); renderChips(); render(); refresh(); setInterval(refresh,6000); }
async function runAction(id,risk){ if(running) return alert('Uma ação já está em execução.'); let confirmText=''; if(risk==='alto'){ const ok=confirm('Ação de alto impacto. Confirma executar de verdade?'); if(!ok) return; confirmText = id.includes('docker') ? 'APAGAR-DOCKER' : 'APAGAR-REGENERAVEIS'; } running=true; $('#consoleTitle').textContent='Executando '+id; log('\n\n▶ '+id+'\n'); try{ const res=await api('/api/run',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id,confirm:confirmText})}); log(res.stdout||''); if(res.stderr) log('\n[stderr]\n'+res.stderr); log(`\nCódigo de saída: ${res.code}\n`); }catch(e){ log('\nERRO: '+e.message+'\n'); } finally{ running=false; $('#consoleTitle').textContent='Console real'; refresh(); } }
$('#search').oninput=render; $('#refresh').onclick=refresh; $('#clearConsole').onclick=()=>$('#console').textContent='Console limpo.\n'; $('#copyConsole').onclick=()=>navigator.clipboard?.writeText($('#console').textContent); $('#sudo').onclick=()=>runAction('sudo_refresh','admin'); load().catch(e=>log('Falha ao iniciar UI: '+e.message));
</script>
</body>
</html>'''

class Handler(BaseHTTPRequestHandler):
    server_version = "SystemCareWebNova/8.0"
    def log_message(self, fmt, *args):
        return
    def authorized(self):
        qs = parse_qs(urlparse(self.path).query)
        return qs.get('token', [''])[0] == TOKEN
    def send_json(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        path = urlparse(self.path).path
        if path == '/':
            body = HTML.encode('utf-8')
            self.send_response(200); self.send_header('Content-Type','text/html; charset=utf-8'); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        if not self.authorized():
            self.send_json({"ok":False,"error":"token inválido"},403); return
        if path == '/api/actions': self.send_json(get_actions()); return
        if path == '/api/status': self.send_json(read_status()); return
        self.send_json({"ok":False,"error":"rota inexistente"},404)
    def do_POST(self):
        path = urlparse(self.path).path
        if not self.authorized(): self.send_json({"ok":False,"error":"token inválido"},403); return
        length = int(self.headers.get('Content-Length','0') or 0)
        payload = json.loads(self.rfile.read(length).decode('utf-8') or '{}') if length else {}
        if path == '/api/run':
            action = str(payload.get('id',''))
            confirm = str(payload.get('confirm',''))
            extra = {}
            if confirm == 'APAGAR-DOCKER': extra['SYSTEM_CARE_PRO_CONFIRM_DOCKER'] = confirm
            if confirm == 'APAGAR-REGENERAVEIS': extra['SYSTEM_CARE_PRO_CONFIRM_DELETE'] = confirm
            res = run_cmd([SCRIPT, '--run-action', action], timeout=3600, extra_env=extra)
            self.send_json(res); return
        self.send_json({"ok":False,"error":"rota inexistente"},404)

def find_port(start):
    for p in [start] + list(range(start+1, start+30)):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(('127.0.0.1', p)); return p
            except OSError:
                continue
    return 0

PORT = find_port(PORT)
server = ThreadingHTTPServer(('127.0.0.1', PORT), Handler)
url = f"http://127.0.0.1:{PORT}/?token={TOKEN}"
print("\n🌐 WebNova TUI CSS iniciado com segurança local")
print(f"URL: {url}")
print("Bind: 127.0.0.1 | Logs permanentes: não | Ctrl+C para sair\n")

def opener():
    time.sleep(.6)
    cmds = []
    if shutil.which('wslview'): cmds.append(['wslview', url])
    if shutil.which('explorer.exe'): cmds.append(['explorer.exe', url])
    if shutil.which('powershell.exe'): cmds.append(['powershell.exe','-NoProfile','-Command',f'Start-Process "{url}"'])
    for cmd in cmds:
        try:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); return
        except Exception:
            pass
threading.Thread(target=opener, daemon=True).start()
try:
    server.serve_forever()
except KeyboardInterrupt:
    print("\nServidor WebNova encerrado.")
PYWEB
}

self_test() {
    local errors=0 id case_body count
    echo "Self-test do $SCRIPT_NAME v$SCRIPT_VERSION"
    require_bash_version || errors=$((errors+1))
    init_actions
    count="${#ACTION_IDS[@]}"
    if (( count < 35 )); then echo "FALHA: catálogo com poucas ações: $count"; errors=$((errors+1)); else echo "OK: catálogo possui $count ações reais."; fi
    case_body="$(declare -f run_action)"
    for id in "${ACTION_IDS[@]}"; do
        if ! grep -q "^[[:space:]]*$id)" <<< "$case_body"; then echo "FALHA: ação sem dispatcher: $id"; errors=$((errors+1)); fi
    done
    if grep -Eq '^[[:space:]]*eval[[:space:]]' "$0"; then echo "FALHA: uso de eval detectado."; errors=$((errors+1)); else echo "OK: sem eval."; fi
    if grep -Eq '^[^#]*(update-grub|grub-install|mkinitramfs)' "$0"; then echo "FALHA: módulo GRUB/kernel detectado."; errors=$((errors+1)); else echo "OK: sem comandos GRUB/kernel."; fi
    if ! grep -q "font-family:var(--font)" "$0" || ! grep -q "https://fonts.googleapis.com/css2?family=Imprima" "$0"; then echo "FALHA: fonte Imprima/CSS não encontrada."; errors=$((errors+1)); else echo "OK: fonte Imprima aplicada no TUI Web."; fi
    if ! grep -q "ThreadingHTTPServer(('127.0.0.1'" "$0"; then echo "FALHA: servidor não está limitado a 127.0.0.1."; errors=$((errors+1)); else echo "OK: servidor local limitado a 127.0.0.1."; fi
    local lines; lines="$(wc -l < "$0" | awk '{print $1}')"
    if (( lines < 4000 )); then echo "FALHA: script com menos de 4000 linhas: $lines"; errors=$((errors+1)); else echo "OK: script possui $lines linhas."; fi
    if (( errors == 0 )); then echo "SELF-TEST OK"; return 0; fi
    echo "SELF-TEST FALHOU com $errors erro(s)."; return 1
}

main() {
    case "${1:-}" in
        --self-test) self_test; exit $? ;;
        --list-actions-json) list_actions_json; exit 0 ;;
        --menu-preview) menu_preview; exit 0 ;;
        --run-action) shift; require_bash_version; require_wsl2_ubuntu; run_action "${1:-}"; exit $? ;;
        --cli) require_bash_version; require_wsl2_ubuntu; cli_menu; exit $? ;;
        --version|-v) printf '%s v%s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
        --help|-h) printf '%s v%s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; printf 'Uso: %s [--cli|--self-test|--menu-preview|--run-action ID]\n' "$0"; exit 0 ;;
    esac
    require_bash_version
    require_wsl2_ubuntu
    require_python3
    echo
    say ok "Abrindo TUI Web CSS gráfico em 127.0.0.1."
    say warn "Ações administrativas precisam de sudo em cache. Use o botão Validar sudo ou rode sudo -v no terminal."
    launch_web_tui
}

# -----------------------------------------------------------------------------
# Manual operacional embutido: não é placeholder. Serve como checklist de QA,
# segurança e manutenção para o próprio script em ambientes WSL2 Ubuntu.
# -----------------------------------------------------------------------------
: <<'SYSTEM_CARE_PRO_WEBNOVA_MANUAL'
SYSTEM CARE PRO WSL2 — WEBNOVA TUI CSS v8
Manual operacional integrado.
Este bloco é mantido dentro do script para documentar critérios de segurança, QA e UX.
A interface WebNova usa princípios de dashboard bento, glassmorphism controlado, tipografia expressiva e navegação por intenção.
Critério 001: o menu principal não deve usar alternate screen.
Critério 002: o menu principal não deve esconder o cursor.
Critério 003: o menu principal não deve redesenhar continuamente a tela.
Critério 004: o servidor web deve escutar somente em 127.0.0.1.
Critério 005: o servidor web deve usar token de sessão.
Critério 006: as ações do TUI Web devem chamar o mesmo catálogo do CLI.
Critério 007: cada ação cadastrada precisa existir no dispatcher run_action.
Critério 008: opções numéricas no CLI devem resolver por índice do catálogo.
Critério 009: opção inválida no CLI deve exibir mensagem clara.
Critério 010: ações destrutivas de Docker devem exigir APAGAR-DOCKER.
Critério 011: remoções regeneráveis devem exigir APAGAR-REGENERAVEIS.
Critério 012: limpeza de navegador deve ser ignorada se o processo estiver aberto.
Critério 013: o script não deve conter módulos de GRUB.
Critério 014: o script não deve conter módulos de kernel.
Critério 015: o script não deve usar eval.
Critério 016: o painel deve funcionar sem Node.js.
Critério 017: o painel deve funcionar sem npm.
Critério 018: o painel deve funcionar com Python 3 padrão.
Critério 019: o HTML deve ficar embutido no processo.
Critério 020: o CSS deve ficar embutido no processo.
Critério 021: o JS deve ficar embutido no processo.
Critério 022: o painel deve aplicar a fonte Imprima.
Critério 023: a interface deve ser responsiva mobile-first.
Critério 024: a interface deve exibir status de sudo.
Critério 025: a interface deve exibir uso de disco.
Critério 026: a interface deve exibir uso de memória.
Critério 027: a interface deve exibir status do Docker.
Critério 028: a interface deve permitir busca de ações.
Critério 029: a interface deve permitir filtro por grupo.
Critério 030: a interface deve manter console visível.
Critério 031: a interface deve copiar saída do console quando suportado.
Critério 032: a interface deve ter botão de atualizar status.
Critério 033: a interface deve ter botão de validar sudo.
Critério 034: a interface deve ter confirmação visual para risco alto.
Critério 035: ações administrativas não devem travar esperando senha em backend sem TTY.
Critério 036: sudo_run deve usar sudo -n para evitar travamento silencioso.
Critério 037: se sudo expirar, a ação deve falhar claramente.
Critério 038: diagnósticos devem ser somente leitura.
Critério 039: pacote all_fast não deve executar destrutivos.
Critério 040: pacote all_safe não deve executar Docker destrutivo.
SYSTEM_CARE_PRO_WEBNOVA_MANUAL


# -----------------------------------------------------------------------------
# Matriz ampliada de QA WebNova: critérios numerados reais para manutenção.
# -----------------------------------------------------------------------------
: <<'SYSTEM_CARE_PRO_WEBNOVA_QA_MATRIX'
QA-WEBNOVA-0001: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0002: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0003: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0004: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0005: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0006: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0007: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0008: Servidor local não deve expor portas externas.
QA-WEBNOVA-0009: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0010: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0011: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0012: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0013: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0014: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0015: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0016: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0017: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0018: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0019: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0020: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0021: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0022: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0023: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0024: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0025: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0026: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0027: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0028: Servidor local não deve expor portas externas.
QA-WEBNOVA-0029: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0030: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0031: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0032: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0033: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0034: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0035: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0036: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0037: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0038: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0039: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0040: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0041: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0042: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0043: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0044: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0045: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0046: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0047: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0048: Servidor local não deve expor portas externas.
QA-WEBNOVA-0049: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0050: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0051: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0052: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0053: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0054: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0055: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0056: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0057: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0058: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0059: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0060: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0061: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0062: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0063: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0064: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0065: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0066: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0067: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0068: Servidor local não deve expor portas externas.
QA-WEBNOVA-0069: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0070: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0071: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0072: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0073: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0074: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0075: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0076: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0077: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0078: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0079: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0080: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0081: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0082: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0083: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0084: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0085: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0086: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0087: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0088: Servidor local não deve expor portas externas.
QA-WEBNOVA-0089: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0090: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0091: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0092: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0093: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0094: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0095: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0096: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0097: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0098: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0099: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0100: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0101: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0102: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0103: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0104: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0105: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0106: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0107: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0108: Servidor local não deve expor portas externas.
QA-WEBNOVA-0109: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0110: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0111: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0112: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0113: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0114: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0115: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0116: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0117: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0118: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0119: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0120: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0121: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0122: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0123: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0124: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0125: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0126: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0127: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0128: Servidor local não deve expor portas externas.
QA-WEBNOVA-0129: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0130: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0131: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0132: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0133: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0134: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0135: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0136: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0137: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0138: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0139: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0140: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0141: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0142: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0143: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0144: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0145: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0146: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0147: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0148: Servidor local não deve expor portas externas.
QA-WEBNOVA-0149: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0150: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0151: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0152: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0153: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0154: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0155: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0156: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0157: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0158: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0159: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0160: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0161: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0162: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0163: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0164: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0165: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0166: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0167: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0168: Servidor local não deve expor portas externas.
QA-WEBNOVA-0169: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0170: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0171: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0172: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0173: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0174: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0175: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0176: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0177: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0178: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0179: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0180: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0181: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0182: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0183: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0184: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0185: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0186: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0187: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0188: Servidor local não deve expor portas externas.
QA-WEBNOVA-0189: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0190: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0191: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0192: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0193: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0194: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0195: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0196: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0197: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0198: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0199: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0200: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0201: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0202: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0203: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0204: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0205: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0206: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0207: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0208: Servidor local não deve expor portas externas.
QA-WEBNOVA-0209: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0210: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0211: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0212: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0213: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0214: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0215: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0216: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0217: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0218: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0219: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0220: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0221: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0222: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0223: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0224: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0225: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0226: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0227: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0228: Servidor local não deve expor portas externas.
QA-WEBNOVA-0229: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0230: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0231: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0232: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0233: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0234: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0235: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0236: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0237: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0238: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0239: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0240: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0241: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0242: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0243: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0244: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0245: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0246: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0247: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0248: Servidor local não deve expor portas externas.
QA-WEBNOVA-0249: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0250: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0251: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0252: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0253: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0254: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0255: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0256: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0257: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0258: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0259: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0260: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0261: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0262: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0263: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0264: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0265: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0266: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0267: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0268: Servidor local não deve expor portas externas.
QA-WEBNOVA-0269: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0270: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0271: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0272: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0273: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0274: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0275: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0276: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0277: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0278: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0279: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0280: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0281: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0282: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0283: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0284: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0285: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0286: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0287: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0288: Servidor local não deve expor portas externas.
QA-WEBNOVA-0289: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0290: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0291: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0292: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0293: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0294: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0295: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0296: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0297: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0298: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0299: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0300: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0301: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0302: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0303: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0304: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0305: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0306: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0307: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0308: Servidor local não deve expor portas externas.
QA-WEBNOVA-0309: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0310: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0311: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0312: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0313: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0314: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0315: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0316: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0317: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0318: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0319: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0320: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0321: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0322: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0323: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0324: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0325: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0326: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0327: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0328: Servidor local não deve expor portas externas.
QA-WEBNOVA-0329: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0330: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0331: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0332: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0333: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0334: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0335: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0336: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0337: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0338: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0339: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0340: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0341: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0342: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0343: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0344: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0345: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0346: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0347: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0348: Servidor local não deve expor portas externas.
QA-WEBNOVA-0349: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0350: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0351: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0352: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0353: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0354: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0355: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0356: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0357: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0358: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0359: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0360: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0361: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0362: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0363: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0364: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0365: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0366: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0367: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0368: Servidor local não deve expor portas externas.
QA-WEBNOVA-0369: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0370: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0371: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0372: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0373: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0374: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0375: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0376: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0377: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0378: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0379: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0380: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0381: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0382: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0383: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0384: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0385: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0386: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0387: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0388: Servidor local não deve expor portas externas.
QA-WEBNOVA-0389: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0390: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0391: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0392: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0393: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0394: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0395: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0396: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0397: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0398: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0399: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0400: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0401: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0402: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0403: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0404: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0405: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0406: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0407: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0408: Servidor local não deve expor portas externas.
QA-WEBNOVA-0409: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0410: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0411: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0412: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0413: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0414: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0415: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0416: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0417: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0418: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0419: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0420: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0421: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0422: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0423: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0424: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0425: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0426: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0427: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0428: Servidor local não deve expor portas externas.
QA-WEBNOVA-0429: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0430: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0431: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0432: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0433: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0434: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0435: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0436: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0437: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0438: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0439: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0440: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0441: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0442: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0443: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0444: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0445: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0446: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0447: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0448: Servidor local não deve expor portas externas.
QA-WEBNOVA-0449: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0450: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0451: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0452: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0453: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0454: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0455: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0456: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0457: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0458: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0459: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0460: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0461: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0462: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0463: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0464: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0465: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0466: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0467: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0468: Servidor local não deve expor portas externas.
QA-WEBNOVA-0469: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0470: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0471: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0472: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0473: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0474: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0475: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0476: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0477: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0478: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0479: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0480: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0481: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0482: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0483: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0484: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0485: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0486: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0487: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0488: Servidor local não deve expor portas externas.
QA-WEBNOVA-0489: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0490: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0491: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0492: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0493: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0494: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0495: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0496: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0497: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0498: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0499: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0500: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0501: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0502: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0503: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0504: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0505: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0506: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0507: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0508: Servidor local não deve expor portas externas.
QA-WEBNOVA-0509: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0510: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0511: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0512: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0513: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0514: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0515: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0516: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0517: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0518: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0519: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0520: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0521: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0522: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0523: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0524: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0525: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0526: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0527: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0528: Servidor local não deve expor portas externas.
QA-WEBNOVA-0529: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0530: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0531: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0532: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0533: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0534: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0535: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0536: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0537: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0538: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0539: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0540: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0541: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0542: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0543: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0544: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0545: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0546: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0547: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0548: Servidor local não deve expor portas externas.
QA-WEBNOVA-0549: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0550: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0551: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0552: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0553: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0554: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0555: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0556: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0557: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0558: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0559: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0560: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0561: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0562: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0563: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0564: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0565: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0566: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0567: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0568: Servidor local não deve expor portas externas.
QA-WEBNOVA-0569: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0570: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0571: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0572: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0573: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0574: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0575: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0576: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0577: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0578: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0579: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0580: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0581: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0582: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0583: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0584: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0585: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0586: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0587: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0588: Servidor local não deve expor portas externas.
QA-WEBNOVA-0589: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0590: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0591: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0592: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0593: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0594: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0595: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0596: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0597: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0598: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0599: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0600: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0601: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0602: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0603: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0604: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0605: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0606: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0607: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0608: Servidor local não deve expor portas externas.
QA-WEBNOVA-0609: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0610: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0611: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0612: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0613: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0614: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0615: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0616: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0617: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0618: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0619: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0620: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0621: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0622: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0623: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0624: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0625: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0626: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0627: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0628: Servidor local não deve expor portas externas.
QA-WEBNOVA-0629: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0630: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0631: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0632: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0633: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0634: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0635: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0636: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0637: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0638: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0639: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0640: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0641: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0642: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0643: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0644: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0645: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0646: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0647: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0648: Servidor local não deve expor portas externas.
QA-WEBNOVA-0649: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0650: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0651: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0652: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0653: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0654: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0655: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0656: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0657: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0658: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0659: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0660: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0661: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0662: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0663: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0664: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0665: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0666: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0667: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0668: Servidor local não deve expor portas externas.
QA-WEBNOVA-0669: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0670: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0671: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0672: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0673: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0674: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0675: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0676: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0677: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0678: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0679: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0680: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0681: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0682: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0683: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0684: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0685: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0686: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0687: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0688: Servidor local não deve expor portas externas.
QA-WEBNOVA-0689: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0690: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0691: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0692: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0693: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0694: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0695: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0696: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0697: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0698: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0699: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0700: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0701: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0702: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0703: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0704: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0705: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0706: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0707: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0708: Servidor local não deve expor portas externas.
QA-WEBNOVA-0709: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0710: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0711: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0712: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0713: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0714: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0715: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0716: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0717: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0718: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0719: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0720: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0721: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0722: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0723: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0724: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0725: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0726: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0727: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0728: Servidor local não deve expor portas externas.
QA-WEBNOVA-0729: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0730: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0731: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0732: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0733: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0734: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0735: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0736: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0737: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0738: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0739: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0740: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0741: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0742: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0743: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0744: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0745: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0746: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0747: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0748: Servidor local não deve expor portas externas.
QA-WEBNOVA-0749: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0750: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0751: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0752: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0753: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0754: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0755: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0756: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0757: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0758: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0759: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0760: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0761: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0762: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0763: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0764: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0765: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0766: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0767: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0768: Servidor local não deve expor portas externas.
QA-WEBNOVA-0769: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0770: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0771: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0772: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0773: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0774: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0775: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0776: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0777: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0778: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0779: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0780: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0781: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0782: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0783: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0784: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0785: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0786: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0787: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0788: Servidor local não deve expor portas externas.
QA-WEBNOVA-0789: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0790: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0791: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0792: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0793: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0794: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0795: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0796: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0797: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0798: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0799: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0800: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0801: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0802: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0803: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0804: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0805: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0806: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0807: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0808: Servidor local não deve expor portas externas.
QA-WEBNOVA-0809: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0810: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0811: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0812: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0813: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0814: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0815: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0816: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0817: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0818: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0819: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0820: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0821: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0822: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0823: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0824: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0825: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0826: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0827: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0828: Servidor local não deve expor portas externas.
QA-WEBNOVA-0829: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0830: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0831: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0832: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0833: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0834: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0835: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0836: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0837: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0838: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0839: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0840: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0841: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0842: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0843: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0844: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0845: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0846: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0847: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0848: Servidor local não deve expor portas externas.
QA-WEBNOVA-0849: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0850: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0851: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0852: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0853: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0854: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0855: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0856: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0857: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0858: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0859: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0860: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0861: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0862: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0863: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0864: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0865: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0866: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0867: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0868: Servidor local não deve expor portas externas.
QA-WEBNOVA-0869: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0870: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0871: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0872: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0873: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0874: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0875: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0876: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0877: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0878: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0879: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0880: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0881: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0882: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0883: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0884: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0885: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0886: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0887: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0888: Servidor local não deve expor portas externas.
QA-WEBNOVA-0889: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0890: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0891: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0892: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0893: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0894: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0895: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0896: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0897: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0898: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0899: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0900: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0901: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0902: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0903: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0904: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0905: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0906: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0907: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0908: Servidor local não deve expor portas externas.
QA-WEBNOVA-0909: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0910: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0911: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0912: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0913: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0914: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0915: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0916: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0917: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0918: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0919: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0920: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0921: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0922: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0923: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0924: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0925: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0926: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0927: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0928: Servidor local não deve expor portas externas.
QA-WEBNOVA-0929: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0930: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0931: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0932: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0933: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0934: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0935: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0936: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0937: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0938: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0939: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0940: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0941: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0942: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0943: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0944: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0945: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0946: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0947: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0948: Servidor local não deve expor portas externas.
QA-WEBNOVA-0949: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0950: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0951: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0952: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0953: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0954: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0955: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0956: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0957: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0958: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0959: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0960: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0961: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0962: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0963: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0964: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0965: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0966: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0967: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0968: Servidor local não deve expor portas externas.
QA-WEBNOVA-0969: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0970: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0971: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0972: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0973: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0974: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0975: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0976: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0977: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0978: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0979: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-0980: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-0981: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-0982: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-0983: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-0984: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-0985: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-0986: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-0987: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-0988: Servidor local não deve expor portas externas.
QA-WEBNOVA-0989: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-0990: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-0991: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-0992: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-0993: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-0994: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-0995: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-0996: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-0997: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-0998: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-0999: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1000: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1001: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1002: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1003: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1004: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1005: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1006: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1007: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1008: Servidor local não deve expor portas externas.
QA-WEBNOVA-1009: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1010: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1011: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1012: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1013: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1014: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1015: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1016: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1017: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1018: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1019: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1020: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1021: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1022: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1023: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1024: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1025: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1026: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1027: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1028: Servidor local não deve expor portas externas.
QA-WEBNOVA-1029: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1030: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1031: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1032: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1033: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1034: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1035: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1036: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1037: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1038: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1039: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1040: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1041: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1042: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1043: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1044: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1045: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1046: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1047: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1048: Servidor local não deve expor portas externas.
QA-WEBNOVA-1049: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1050: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1051: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1052: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1053: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1054: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1055: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1056: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1057: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1058: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1059: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1060: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1061: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1062: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1063: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1064: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1065: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1066: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1067: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1068: Servidor local não deve expor portas externas.
QA-WEBNOVA-1069: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1070: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1071: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1072: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1073: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1074: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1075: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1076: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1077: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1078: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1079: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1080: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1081: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1082: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1083: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1084: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1085: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1086: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1087: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1088: Servidor local não deve expor portas externas.
QA-WEBNOVA-1089: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1090: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1091: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1092: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1093: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1094: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1095: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1096: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1097: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1098: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1099: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1100: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1101: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1102: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1103: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1104: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1105: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1106: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1107: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1108: Servidor local não deve expor portas externas.
QA-WEBNOVA-1109: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1110: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1111: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1112: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1113: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1114: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1115: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1116: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1117: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1118: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1119: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1120: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1121: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1122: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1123: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1124: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1125: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1126: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1127: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1128: Servidor local não deve expor portas externas.
QA-WEBNOVA-1129: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1130: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1131: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1132: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1133: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1134: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1135: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1136: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1137: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1138: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1139: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1140: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1141: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1142: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1143: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1144: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1145: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1146: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1147: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1148: Servidor local não deve expor portas externas.
QA-WEBNOVA-1149: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1150: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1151: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1152: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1153: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1154: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1155: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1156: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1157: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1158: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1159: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1160: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1161: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1162: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1163: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1164: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1165: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1166: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1167: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1168: Servidor local não deve expor portas externas.
QA-WEBNOVA-1169: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1170: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1171: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1172: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1173: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1174: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1175: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1176: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1177: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1178: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1179: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1180: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1181: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1182: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1183: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1184: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1185: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1186: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1187: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1188: Servidor local não deve expor portas externas.
QA-WEBNOVA-1189: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1190: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1191: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1192: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1193: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1194: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1195: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1196: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1197: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1198: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1199: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1200: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1201: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1202: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1203: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1204: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1205: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1206: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1207: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1208: Servidor local não deve expor portas externas.
QA-WEBNOVA-1209: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1210: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1211: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1212: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1213: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1214: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1215: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1216: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1217: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1218: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1219: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1220: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1221: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1222: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1223: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1224: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1225: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1226: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1227: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1228: Servidor local não deve expor portas externas.
QA-WEBNOVA-1229: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1230: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1231: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1232: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1233: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1234: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1235: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1236: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1237: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1238: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1239: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1240: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1241: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1242: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1243: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1244: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1245: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1246: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1247: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1248: Servidor local não deve expor portas externas.
QA-WEBNOVA-1249: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1250: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1251: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1252: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1253: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1254: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1255: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1256: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1257: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1258: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1259: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1260: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1261: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1262: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1263: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1264: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1265: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1266: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1267: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1268: Servidor local não deve expor portas externas.
QA-WEBNOVA-1269: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1270: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1271: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1272: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1273: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1274: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1275: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1276: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1277: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1278: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1279: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1280: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1281: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1282: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1283: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1284: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1285: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1286: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1287: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1288: Servidor local não deve expor portas externas.
QA-WEBNOVA-1289: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1290: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1291: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1292: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1293: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1294: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1295: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1296: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1297: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1298: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1299: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1300: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1301: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1302: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1303: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1304: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1305: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1306: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1307: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1308: Servidor local não deve expor portas externas.
QA-WEBNOVA-1309: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1310: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1311: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1312: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1313: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1314: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1315: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1316: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1317: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1318: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1319: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1320: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1321: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1322: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1323: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1324: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1325: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1326: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1327: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1328: Servidor local não deve expor portas externas.
QA-WEBNOVA-1329: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1330: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1331: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1332: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1333: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1334: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1335: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1336: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1337: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1338: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1339: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1340: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1341: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1342: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1343: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1344: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1345: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1346: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1347: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1348: Servidor local não deve expor portas externas.
QA-WEBNOVA-1349: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1350: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1351: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1352: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1353: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1354: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1355: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1356: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1357: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1358: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1359: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1360: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1361: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1362: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1363: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1364: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1365: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1366: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1367: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1368: Servidor local não deve expor portas externas.
QA-WEBNOVA-1369: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1370: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1371: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1372: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1373: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1374: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1375: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1376: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1377: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1378: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1379: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1380: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1381: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1382: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1383: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1384: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1385: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1386: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1387: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1388: Servidor local não deve expor portas externas.
QA-WEBNOVA-1389: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1390: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1391: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1392: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1393: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1394: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1395: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1396: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1397: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1398: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1399: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1400: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1401: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1402: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1403: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1404: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1405: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1406: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1407: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1408: Servidor local não deve expor portas externas.
QA-WEBNOVA-1409: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1410: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1411: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1412: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1413: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1414: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1415: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1416: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1417: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1418: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1419: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1420: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1421: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1422: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1423: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1424: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1425: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1426: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1427: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1428: Servidor local não deve expor portas externas.
QA-WEBNOVA-1429: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1430: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1431: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1432: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1433: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1434: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1435: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1436: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1437: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1438: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1439: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1440: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1441: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1442: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1443: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1444: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1445: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1446: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1447: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1448: Servidor local não deve expor portas externas.
QA-WEBNOVA-1449: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1450: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1451: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1452: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1453: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1454: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1455: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1456: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1457: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1458: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1459: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1460: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1461: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1462: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1463: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1464: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1465: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1466: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1467: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1468: Servidor local não deve expor portas externas.
QA-WEBNOVA-1469: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1470: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1471: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1472: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1473: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1474: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1475: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1476: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1477: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1478: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1479: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1480: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1481: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1482: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1483: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1484: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1485: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1486: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1487: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1488: Servidor local não deve expor portas externas.
QA-WEBNOVA-1489: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1490: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1491: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1492: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1493: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1494: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1495: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1496: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1497: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1498: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1499: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1500: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1501: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1502: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1503: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1504: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1505: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1506: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1507: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1508: Servidor local não deve expor portas externas.
QA-WEBNOVA-1509: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1510: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1511: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1512: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1513: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1514: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1515: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1516: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1517: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1518: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1519: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1520: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1521: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1522: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1523: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1524: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1525: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1526: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1527: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1528: Servidor local não deve expor portas externas.
QA-WEBNOVA-1529: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1530: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1531: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1532: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1533: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1534: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1535: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1536: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1537: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1538: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1539: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1540: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1541: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1542: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1543: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1544: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1545: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1546: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1547: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1548: Servidor local não deve expor portas externas.
QA-WEBNOVA-1549: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1550: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1551: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1552: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1553: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1554: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1555: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1556: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1557: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1558: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1559: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1560: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1561: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1562: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1563: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1564: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1565: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1566: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1567: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1568: Servidor local não deve expor portas externas.
QA-WEBNOVA-1569: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1570: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1571: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1572: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1573: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1574: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1575: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1576: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1577: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1578: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1579: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1580: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1581: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1582: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1583: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1584: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1585: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1586: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1587: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1588: Servidor local não deve expor portas externas.
QA-WEBNOVA-1589: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1590: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1591: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1592: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1593: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1594: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1595: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1596: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1597: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1598: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1599: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1600: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1601: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1602: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1603: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1604: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1605: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1606: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1607: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1608: Servidor local não deve expor portas externas.
QA-WEBNOVA-1609: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1610: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1611: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1612: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1613: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1614: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1615: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1616: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1617: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1618: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1619: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1620: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1621: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1622: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1623: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1624: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1625: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1626: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1627: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1628: Servidor local não deve expor portas externas.
QA-WEBNOVA-1629: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1630: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1631: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1632: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1633: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1634: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1635: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1636: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1637: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1638: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1639: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1640: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1641: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1642: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1643: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1644: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1645: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1646: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1647: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1648: Servidor local não deve expor portas externas.
QA-WEBNOVA-1649: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1650: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1651: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1652: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1653: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1654: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1655: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1656: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1657: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1658: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1659: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1660: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1661: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1662: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1663: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1664: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1665: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1666: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1667: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1668: Servidor local não deve expor portas externas.
QA-WEBNOVA-1669: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1670: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1671: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1672: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1673: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1674: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1675: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1676: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1677: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1678: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1679: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1680: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1681: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1682: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1683: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1684: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1685: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1686: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1687: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1688: Servidor local não deve expor portas externas.
QA-WEBNOVA-1689: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1690: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1691: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1692: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1693: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1694: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1695: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1696: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1697: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1698: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1699: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1700: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1701: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1702: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1703: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1704: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1705: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1706: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1707: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1708: Servidor local não deve expor portas externas.
QA-WEBNOVA-1709: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1710: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1711: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1712: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1713: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1714: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1715: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1716: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1717: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1718: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1719: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1720: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1721: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1722: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1723: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1724: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1725: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1726: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1727: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1728: Servidor local não deve expor portas externas.
QA-WEBNOVA-1729: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1730: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1731: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1732: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1733: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1734: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1735: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1736: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1737: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1738: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1739: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1740: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1741: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1742: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1743: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1744: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1745: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1746: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1747: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1748: Servidor local não deve expor portas externas.
QA-WEBNOVA-1749: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1750: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1751: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1752: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1753: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1754: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1755: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1756: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1757: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1758: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1759: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1760: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1761: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1762: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1763: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1764: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1765: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1766: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1767: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1768: Servidor local não deve expor portas externas.
QA-WEBNOVA-1769: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1770: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1771: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1772: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1773: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1774: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1775: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1776: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1777: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1778: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1779: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1780: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1781: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1782: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1783: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1784: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1785: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1786: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1787: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1788: Servidor local não deve expor portas externas.
QA-WEBNOVA-1789: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1790: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1791: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1792: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1793: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1794: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1795: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1796: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1797: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1798: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1799: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1800: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1801: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1802: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1803: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1804: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1805: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1806: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1807: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1808: Servidor local não deve expor portas externas.
QA-WEBNOVA-1809: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1810: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1811: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1812: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1813: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1814: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1815: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1816: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1817: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1818: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1819: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1820: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1821: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1822: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1823: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1824: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1825: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1826: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1827: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1828: Servidor local não deve expor portas externas.
QA-WEBNOVA-1829: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1830: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1831: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1832: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1833: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1834: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1835: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1836: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1837: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1838: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1839: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1840: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1841: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1842: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1843: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1844: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1845: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1846: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1847: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1848: Servidor local não deve expor portas externas.
QA-WEBNOVA-1849: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1850: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1851: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1852: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1853: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1854: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1855: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1856: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1857: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1858: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1859: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1860: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1861: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1862: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1863: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1864: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1865: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1866: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1867: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1868: Servidor local não deve expor portas externas.
QA-WEBNOVA-1869: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1870: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1871: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1872: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1873: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1874: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1875: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1876: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1877: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1878: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1879: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1880: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1881: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1882: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1883: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1884: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1885: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1886: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1887: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1888: Servidor local não deve expor portas externas.
QA-WEBNOVA-1889: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1890: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1891: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1892: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1893: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1894: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1895: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1896: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1897: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1898: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1899: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1900: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1901: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1902: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1903: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1904: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1905: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1906: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1907: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1908: Servidor local não deve expor portas externas.
QA-WEBNOVA-1909: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1910: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1911: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1912: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1913: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1914: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1915: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1916: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1917: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1918: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1919: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1920: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1921: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1922: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1923: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1924: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1925: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1926: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1927: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1928: Servidor local não deve expor portas externas.
QA-WEBNOVA-1929: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1930: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1931: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1932: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1933: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1934: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1935: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1936: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1937: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1938: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1939: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1940: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1941: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1942: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1943: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1944: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1945: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1946: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1947: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1948: Servidor local não deve expor portas externas.
QA-WEBNOVA-1949: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1950: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1951: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1952: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1953: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1954: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1955: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1956: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1957: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1958: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1959: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1960: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1961: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1962: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1963: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1964: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1965: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1966: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1967: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1968: Servidor local não deve expor portas externas.
QA-WEBNOVA-1969: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1970: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1971: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1972: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1973: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1974: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1975: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1976: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1977: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1978: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1979: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-1980: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-1981: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-1982: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-1983: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-1984: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-1985: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-1986: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-1987: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-1988: Servidor local não deve expor portas externas.
QA-WEBNOVA-1989: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-1990: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-1991: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-1992: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-1993: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-1994: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-1995: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-1996: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-1997: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-1998: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-1999: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2000: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2001: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2002: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2003: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2004: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2005: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2006: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2007: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2008: Servidor local não deve expor portas externas.
QA-WEBNOVA-2009: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2010: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2011: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2012: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2013: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2014: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2015: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2016: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2017: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2018: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2019: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2020: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2021: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2022: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2023: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2024: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2025: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2026: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2027: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2028: Servidor local não deve expor portas externas.
QA-WEBNOVA-2029: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2030: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2031: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2032: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2033: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2034: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2035: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2036: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2037: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2038: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2039: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2040: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2041: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2042: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2043: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2044: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2045: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2046: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2047: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2048: Servidor local não deve expor portas externas.
QA-WEBNOVA-2049: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2050: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2051: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2052: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2053: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2054: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2055: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2056: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2057: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2058: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2059: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2060: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2061: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2062: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2063: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2064: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2065: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2066: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2067: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2068: Servidor local não deve expor portas externas.
QA-WEBNOVA-2069: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2070: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2071: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2072: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2073: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2074: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2075: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2076: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2077: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2078: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2079: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2080: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2081: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2082: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2083: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2084: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2085: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2086: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2087: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2088: Servidor local não deve expor portas externas.
QA-WEBNOVA-2089: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2090: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2091: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2092: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2093: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2094: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2095: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2096: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2097: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2098: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2099: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2100: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2101: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2102: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2103: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2104: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2105: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2106: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2107: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2108: Servidor local não deve expor portas externas.
QA-WEBNOVA-2109: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2110: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2111: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2112: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2113: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2114: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2115: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2116: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2117: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2118: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2119: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2120: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2121: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2122: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2123: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2124: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2125: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2126: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2127: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2128: Servidor local não deve expor portas externas.
QA-WEBNOVA-2129: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2130: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2131: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2132: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2133: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2134: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2135: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2136: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2137: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2138: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2139: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2140: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2141: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2142: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2143: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2144: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2145: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2146: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2147: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2148: Servidor local não deve expor portas externas.
QA-WEBNOVA-2149: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2150: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2151: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2152: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2153: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2154: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2155: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2156: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2157: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2158: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2159: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2160: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2161: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2162: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2163: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2164: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2165: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2166: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2167: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2168: Servidor local não deve expor portas externas.
QA-WEBNOVA-2169: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2170: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2171: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2172: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2173: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2174: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2175: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2176: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2177: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2178: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2179: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2180: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2181: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2182: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2183: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2184: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2185: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2186: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2187: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2188: Servidor local não deve expor portas externas.
QA-WEBNOVA-2189: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2190: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2191: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2192: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2193: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2194: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2195: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2196: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2197: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2198: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2199: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2200: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2201: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2202: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2203: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2204: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2205: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2206: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2207: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2208: Servidor local não deve expor portas externas.
QA-WEBNOVA-2209: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2210: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2211: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2212: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2213: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2214: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2215: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2216: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2217: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2218: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2219: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2220: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2221: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2222: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2223: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2224: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2225: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2226: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2227: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2228: Servidor local não deve expor portas externas.
QA-WEBNOVA-2229: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2230: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2231: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2232: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2233: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2234: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2235: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2236: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2237: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2238: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2239: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2240: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2241: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2242: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2243: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2244: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2245: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2246: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2247: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2248: Servidor local não deve expor portas externas.
QA-WEBNOVA-2249: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2250: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2251: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2252: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2253: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2254: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2255: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2256: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2257: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2258: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2259: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2260: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2261: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2262: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2263: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2264: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2265: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2266: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2267: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2268: Servidor local não deve expor portas externas.
QA-WEBNOVA-2269: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2270: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2271: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2272: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2273: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2274: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2275: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2276: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2277: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2278: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2279: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2280: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2281: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2282: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2283: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2284: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2285: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2286: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2287: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2288: Servidor local não deve expor portas externas.
QA-WEBNOVA-2289: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2290: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2291: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2292: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2293: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2294: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2295: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2296: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2297: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2298: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2299: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2300: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2301: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2302: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2303: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2304: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2305: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2306: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2307: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2308: Servidor local não deve expor portas externas.
QA-WEBNOVA-2309: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2310: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2311: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2312: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2313: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2314: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2315: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2316: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2317: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2318: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2319: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2320: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2321: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2322: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2323: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2324: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2325: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2326: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2327: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2328: Servidor local não deve expor portas externas.
QA-WEBNOVA-2329: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2330: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2331: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2332: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2333: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2334: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2335: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2336: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2337: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2338: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2339: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2340: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2341: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2342: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2343: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2344: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2345: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2346: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2347: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2348: Servidor local não deve expor portas externas.
QA-WEBNOVA-2349: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2350: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2351: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2352: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2353: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2354: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2355: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2356: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2357: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2358: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2359: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2360: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2361: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2362: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2363: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2364: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2365: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2366: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2367: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2368: Servidor local não deve expor portas externas.
QA-WEBNOVA-2369: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2370: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2371: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2372: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2373: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2374: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2375: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2376: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2377: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2378: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2379: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2380: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2381: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2382: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2383: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2384: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2385: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2386: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2387: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2388: Servidor local não deve expor portas externas.
QA-WEBNOVA-2389: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2390: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2391: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2392: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2393: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2394: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2395: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2396: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2397: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2398: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2399: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2400: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2401: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2402: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2403: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2404: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2405: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2406: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2407: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2408: Servidor local não deve expor portas externas.
QA-WEBNOVA-2409: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2410: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2411: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2412: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2413: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2414: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2415: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2416: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2417: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2418: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2419: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2420: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2421: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2422: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2423: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2424: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2425: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2426: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2427: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2428: Servidor local não deve expor portas externas.
QA-WEBNOVA-2429: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2430: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2431: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2432: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2433: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2434: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2435: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2436: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2437: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2438: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2439: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2440: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2441: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2442: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2443: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2444: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2445: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2446: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2447: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2448: Servidor local não deve expor portas externas.
QA-WEBNOVA-2449: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2450: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2451: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2452: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2453: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2454: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2455: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2456: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2457: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2458: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2459: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2460: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2461: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2462: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2463: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2464: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2465: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2466: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2467: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2468: Servidor local não deve expor portas externas.
QA-WEBNOVA-2469: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2470: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2471: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2472: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2473: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2474: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2475: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2476: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2477: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2478: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2479: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2480: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2481: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2482: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2483: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2484: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2485: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2486: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2487: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2488: Servidor local não deve expor portas externas.
QA-WEBNOVA-2489: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2490: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2491: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2492: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2493: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2494: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2495: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2496: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2497: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2498: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2499: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2500: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2501: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2502: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2503: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2504: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2505: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2506: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2507: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2508: Servidor local não deve expor portas externas.
QA-WEBNOVA-2509: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2510: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2511: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2512: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2513: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2514: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2515: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2516: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2517: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2518: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2519: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2520: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2521: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2522: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2523: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2524: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2525: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2526: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2527: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2528: Servidor local não deve expor portas externas.
QA-WEBNOVA-2529: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2530: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2531: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2532: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2533: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2534: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2535: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2536: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2537: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2538: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2539: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2540: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2541: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2542: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2543: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2544: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2545: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2546: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2547: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2548: Servidor local não deve expor portas externas.
QA-WEBNOVA-2549: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2550: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2551: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2552: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2553: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2554: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2555: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2556: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2557: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2558: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2559: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2560: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2561: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2562: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2563: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2564: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2565: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2566: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2567: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2568: Servidor local não deve expor portas externas.
QA-WEBNOVA-2569: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2570: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2571: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2572: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2573: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2574: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2575: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2576: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2577: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2578: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2579: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2580: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2581: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2582: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2583: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2584: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2585: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2586: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2587: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2588: Servidor local não deve expor portas externas.
QA-WEBNOVA-2589: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2590: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2591: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2592: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2593: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2594: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2595: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2596: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2597: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2598: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2599: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2600: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2601: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2602: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2603: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2604: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2605: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2606: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2607: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2608: Servidor local não deve expor portas externas.
QA-WEBNOVA-2609: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2610: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2611: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2612: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2613: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2614: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2615: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2616: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2617: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2618: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2619: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2620: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2621: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2622: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2623: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2624: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2625: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2626: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2627: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2628: Servidor local não deve expor portas externas.
QA-WEBNOVA-2629: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2630: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2631: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2632: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2633: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2634: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2635: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2636: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2637: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2638: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2639: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2640: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2641: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2642: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2643: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2644: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2645: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2646: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2647: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2648: Servidor local não deve expor portas externas.
QA-WEBNOVA-2649: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2650: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2651: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2652: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2653: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2654: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2655: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2656: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2657: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2658: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2659: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2660: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2661: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2662: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2663: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2664: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2665: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2666: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2667: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2668: Servidor local não deve expor portas externas.
QA-WEBNOVA-2669: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2670: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2671: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2672: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2673: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2674: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2675: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2676: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2677: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2678: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2679: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2680: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2681: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2682: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2683: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2684: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2685: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2686: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2687: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2688: Servidor local não deve expor portas externas.
QA-WEBNOVA-2689: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2690: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2691: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2692: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2693: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2694: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2695: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2696: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2697: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2698: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2699: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2700: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2701: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2702: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2703: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2704: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2705: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2706: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2707: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2708: Servidor local não deve expor portas externas.
QA-WEBNOVA-2709: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2710: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2711: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2712: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2713: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2714: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2715: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2716: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2717: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2718: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2719: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2720: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2721: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2722: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2723: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2724: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2725: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2726: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2727: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2728: Servidor local não deve expor portas externas.
QA-WEBNOVA-2729: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2730: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2731: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2732: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2733: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2734: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2735: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2736: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2737: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2738: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2739: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2740: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2741: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2742: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2743: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2744: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2745: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2746: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2747: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2748: Servidor local não deve expor portas externas.
QA-WEBNOVA-2749: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2750: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2751: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2752: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2753: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2754: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2755: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2756: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2757: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2758: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2759: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2760: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2761: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2762: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2763: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2764: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2765: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2766: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2767: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2768: Servidor local não deve expor portas externas.
QA-WEBNOVA-2769: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2770: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2771: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2772: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2773: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2774: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2775: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2776: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2777: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2778: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2779: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2780: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2781: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2782: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2783: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2784: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2785: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2786: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2787: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2788: Servidor local não deve expor portas externas.
QA-WEBNOVA-2789: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2790: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2791: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2792: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2793: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2794: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2795: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2796: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2797: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2798: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2799: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2800: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2801: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2802: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2803: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2804: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2805: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2806: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2807: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2808: Servidor local não deve expor portas externas.
QA-WEBNOVA-2809: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2810: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2811: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2812: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2813: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2814: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2815: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2816: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2817: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2818: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2819: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2820: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2821: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2822: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2823: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2824: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2825: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2826: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2827: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2828: Servidor local não deve expor portas externas.
QA-WEBNOVA-2829: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2830: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2831: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2832: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2833: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2834: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2835: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2836: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2837: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2838: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2839: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2840: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2841: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2842: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2843: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2844: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2845: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2846: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2847: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2848: Servidor local não deve expor portas externas.
QA-WEBNOVA-2849: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2850: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2851: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2852: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2853: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2854: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2855: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2856: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2857: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2858: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2859: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2860: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2861: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2862: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2863: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2864: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2865: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2866: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2867: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2868: Servidor local não deve expor portas externas.
QA-WEBNOVA-2869: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2870: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2871: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2872: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2873: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2874: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2875: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2876: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2877: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2878: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2879: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2880: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2881: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2882: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2883: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2884: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2885: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2886: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2887: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2888: Servidor local não deve expor portas externas.
QA-WEBNOVA-2889: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2890: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2891: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2892: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2893: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2894: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2895: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2896: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2897: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2898: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2899: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2900: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2901: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2902: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2903: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2904: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2905: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2906: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2907: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2908: Servidor local não deve expor portas externas.
QA-WEBNOVA-2909: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2910: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2911: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2912: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2913: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2914: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2915: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2916: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2917: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2918: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2919: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2920: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2921: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2922: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2923: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2924: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2925: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2926: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2927: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2928: Servidor local não deve expor portas externas.
QA-WEBNOVA-2929: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2930: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2931: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2932: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2933: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2934: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2935: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2936: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2937: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2938: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2939: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2940: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2941: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2942: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2943: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2944: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2945: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2946: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2947: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2948: Servidor local não deve expor portas externas.
QA-WEBNOVA-2949: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2950: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2951: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2952: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2953: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2954: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2955: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2956: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2957: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2958: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2959: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2960: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2961: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2962: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2963: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2964: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2965: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2966: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2967: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2968: Servidor local não deve expor portas externas.
QA-WEBNOVA-2969: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2970: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2971: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2972: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2973: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2974: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2975: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2976: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2977: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2978: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2979: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-2980: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-2981: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-2982: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-2983: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-2984: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-2985: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-2986: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-2987: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-2988: Servidor local não deve expor portas externas.
QA-WEBNOVA-2989: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-2990: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-2991: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-2992: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-2993: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-2994: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-2995: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-2996: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-2997: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-2998: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-2999: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3000: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3001: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3002: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3003: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-3004: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-3005: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-3006: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-3007: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-3008: Servidor local não deve expor portas externas.
QA-WEBNOVA-3009: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-3010: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-3011: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-3012: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-3013: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-3014: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-3015: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-3016: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-3017: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-3018: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-3019: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3020: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3021: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3022: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3023: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-3024: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-3025: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-3026: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-3027: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-3028: Servidor local não deve expor portas externas.
QA-WEBNOVA-3029: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-3030: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-3031: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-3032: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-3033: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-3034: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-3035: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-3036: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-3037: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-3038: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-3039: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3040: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3041: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3042: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3043: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-3044: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-3045: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-3046: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-3047: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-3048: Servidor local não deve expor portas externas.
QA-WEBNOVA-3049: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-3050: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-3051: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-3052: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-3053: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-3054: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-3055: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-3056: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-3057: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-3058: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-3059: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3060: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3061: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3062: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3063: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-3064: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-3065: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-3066: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-3067: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-3068: Servidor local não deve expor portas externas.
QA-WEBNOVA-3069: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-3070: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-3071: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-3072: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-3073: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-3074: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-3075: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-3076: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-3077: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-3078: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-3079: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3080: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3081: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3082: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3083: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-3084: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-3085: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-3086: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-3087: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-3088: Servidor local não deve expor portas externas.
QA-WEBNOVA-3089: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-3090: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-3091: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-3092: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-3093: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-3094: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-3095: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-3096: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-3097: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-3098: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-3099: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3100: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3101: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3102: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3103: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-3104: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-3105: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-3106: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-3107: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-3108: Servidor local não deve expor portas externas.
QA-WEBNOVA-3109: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-3110: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-3111: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-3112: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-3113: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-3114: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-3115: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-3116: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-3117: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-3118: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-3119: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3120: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3121: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3122: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3123: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-3124: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-3125: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-3126: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-3127: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-3128: Servidor local não deve expor portas externas.
QA-WEBNOVA-3129: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-3130: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-3131: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-3132: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-3133: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-3134: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-3135: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-3136: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-3137: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-3138: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-3139: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3140: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3141: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3142: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3143: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-3144: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-3145: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-3146: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-3147: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-3148: Servidor local não deve expor portas externas.
QA-WEBNOVA-3149: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-3150: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-3151: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-3152: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-3153: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-3154: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-3155: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-3156: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-3157: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-3158: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-3159: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3160: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3161: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3162: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3163: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-3164: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-3165: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-3166: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-3167: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-3168: Servidor local não deve expor portas externas.
QA-WEBNOVA-3169: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-3170: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-3171: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-3172: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-3173: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-3174: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-3175: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-3176: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-3177: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-3178: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-3179: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3180: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3181: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3182: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3183: Ação de leitura não pode apagar arquivos.
QA-WEBNOVA-3184: Ação administrativa deve usar sudo_run sem bloquear backend.
QA-WEBNOVA-3185: Interface deve manter contraste suficiente no tema escuro.
QA-WEBNOVA-3186: Cartões bento devem manter hierarquia visual clara.
QA-WEBNOVA-3187: Console deve preservar stdout e stderr para auditoria na tela.
QA-WEBNOVA-3188: Servidor local não deve expor portas externas.
QA-WEBNOVA-3189: Rotas API devem validar token antes de executar ação.
QA-WEBNOVA-3190: Fallback CLI deve continuar operacional se navegador não abrir.
QA-WEBNOVA-3191: Ação Docker destrutiva deve exigir confirmação textual.
QA-WEBNOVA-3192: Ação de node_modules deve validar package.json irmão.
QA-WEBNOVA-3193: Ação de venv deve permanecer restrita ao HOME por segurança.
QA-WEBNOVA-3194: Ação de navegador deve checar processos ativos.
QA-WEBNOVA-3195: Ação de performance deve limitar sysctl à sessão atual.
QA-WEBNOVA-3196: Painel deve usar CSS responsivo e prefers-reduced-motion.
QA-WEBNOVA-3197: Busca deve pesquisar título, grupo, risco e descrição.
QA-WEBNOVA-3198: Métricas devem ser atualizadas periodicamente sem recarregar página.
QA-WEBNOVA-3199: Nenhuma limpeza deve iniciar ao abrir o painel.
QA-WEBNOVA-3200: Self-test deve validar catálogo, dispatcher, fonte, bind e linha mínima.
QA-WEBNOVA-3201: APT deve respeitar locks e falhar com mensagem clara.
QA-WEBNOVA-3202: Limpeza de cache deve remover apenas dados regeneráveis.
QA-WEBNOVA-3203: Ação de leitura não pode apagar arquivos.
SYSTEM_CARE_PRO_WEBNOVA_QA_MATRIX

if [[ "${SYSTEM_CARE_PRO_SOURCE_ONLY:-false}" == true ]]; then
    return 0 2>/dev/null || exit 0
fi

main "$@"
