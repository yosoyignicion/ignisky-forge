#!/usr/bin/env bash
#
# ignisky-forge — La forja de tus perfiles Hermes 🔥
# Gestión, clonación, fusión y sincronización de perfiles Hermes Agent.
#
# Versión:    1.0.0
# Licencia:   MIT
# Autor:      IgnicionDev (yosoyignicion)
# Marca:      ignisky-* por Ignición 🔥
#
# Uso:        ./ignisky-forge.sh [opciones]
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#  CONFIG
# ═══════════════════════════════════════════════════════════════

VERSION="1.0.0"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PROFILES_DIR="${HERMES_HOME}/profiles"
BACKUP_BASE="${HERMES_HOME}/backups"
FORGE_BACKUP_DIR="${BACKUP_BASE}/forge"

# ═══════════════════════════════════════════════════════════════
#  PALETA IGNICIÓN
# ═══════════════════════════════════════════════════════════════

ESC=$(printf '\\033')
RED="${ESC}[38;2;237;33;0m"
_DARK="${ESC}[38;2;5;5;5m"
_LIGHT="${ESC}[38;2;229;229;229m"
GRAY="${ESC}[38;2;100;100;100m"
GREEN="${ESC}[38;2;0;200;100m"
YELLOW="${ESC}[38;2;255;200;0m"
BLUE="${ESC}[38;2;0;150;255m"
BOLD="${ESC}[1m"
NC="${ESC}[0m"
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"

# ═══════════════════════════════════════════════════════════════
#  UTILIDADES
# ═══════════════════════════════════════════════════════════════

log()    { echo -e "  ${GREEN}${BOLD}→${NC} $*"; }
warn()   { echo -e "  ${YELLOW}${BOLD}!${NC} $*"; }
error()  { echo -e "  ${RED}${BOLD}✖${NC} $*" >&2; }
die()    { error "$*"; exit 1; }
header() { echo -e "\n${RED}${BOLD}═══ $* ═══${NC}\n"; }
dim()    { echo -e "${GRAY}$*${NC}"; }

draw_box() {
    local title="$1"
    local width=58
    local _padding=2
    echo -e "${RED}${BOLD}┌─${title} ${NC}${GRAY}$(printf '─%.0s' $(seq 1 $((width - ${#title} - 4))))${NC}"
}

box_item() { echo -e "  ${GRAY}│${NC}  $*"; }
box_end()  { echo -e "  ${GRAY}└$(printf '─%.0s' $(seq 1 56))${NC}\n"; }

# ═══════════════════════════════════════════════════════════════
#  FUNCIONES CORE — Detección y perfiles
# ═══════════════════════════════════════════════════════════════

detect_hermes() {
    if command -v hermes &>/dev/null; then
        log "Hermes Agent detectado: ${BOLD}$(hermes --version 2>&1 | head -1)${NC}"
        return 0
    fi
    if [[ -d "$PROFILES_DIR" ]]; then
        warn "Hermes CLI no está en PATH, pero existe el directorio de perfiles"
        return 0
    fi
    error "No se detectó Hermes Agent. Perfiles no encontrados en ${PROFILES_DIR}"
    error "Instala Hermes primero: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
    return 1
}

list_profiles() {
    header "📋 Perfiles Hermes disponibles"
    if [[ ! -d "$PROFILES_DIR" ]]; then
        warn "No existe el directorio de perfiles: ${PROFILES_DIR}"
        return 1
    fi

    local profiles=()
    while IFS= read -r dir; do
        profiles+=("$(basename "$dir")")
    done < <(find "$PROFILES_DIR" -maxdepth 1 -type d | sort | tail -n +2)

    if [[ ${#profiles[@]} -eq 0 ]]; then
        warn "No se encontraron perfiles en ${PROFILES_DIR}"
        return 1
    fi

    for profile in "${profiles[@]}"; do
        local size
        size=$(du -sh "${PROFILES_DIR}/${profile}" 2>/dev/null | cut -f1)
        local has_config=""
        [[ -f "${PROFILES_DIR}/${profile}/config.yaml" ]] && has_config="${CHECK}"
        local has_skills=""
        [[ -d "${PROFILES_DIR}/${profile}/skills" ]] && has_skills="${GREEN}🧰${NC}"
        local has_memories=""
        [[ -d "${PROFILES_DIR}/${profile}/memories" ]] && has_memories="${BLUE}🧠${NC}"

        echo -e "  ${GRAY}│${NC}  ${RED}🔥${NC} ${BOLD}$profile${NC}"
        echo -e "  ${GRAY}│${NC}     ${GRAY}Tamaño:${NC} $size  ${has_config} ${has_skills} ${has_memories}"
        echo -e "  ${GRAY}│${NC}"
    done

    echo -e "  ${GRAY}Total: ${BOLD}${#profiles[@]}${NC} ${GRAY}perfiles encontrados${NC}"
    return 0
}

get_profile_list() {
    local -n _result="$1"
    _result=()
    if [[ ! -d "$PROFILES_DIR" ]]; then
        return 1
    fi
    while IFS= read -r dir; do
        _result+=("$(basename "$dir")")
    done < <(find "$PROFILES_DIR" -maxdepth 1 -type d | sort | tail -n +2)
}

profile_exists() {
    local name="$1"
    [[ -d "${PROFILES_DIR}/${name}" ]]
}

validate_profile() {
    local name="$1"
    if ! profile_exists "$name"; then
        die "El perfil '${name}' no existe en ${PROFILES_DIR}"
    fi
}

select_profile() {
    local prompt="$1"
    local -n _selected="$2"
    local profiles=()
    get_profile_list profiles
    if [[ ${#profiles[@]} -eq 0 ]]; then
        die "No hay perfiles disponibles"
    fi
    echo -e "  ${BOLD}$prompt${NC}"
    local i=1
    declare -a pnames
    for p in "${profiles[@]}"; do
        pnames[i]="$p"
        echo -e "  ${GRAY}│${NC}  ${BOLD}$i${NC}  $p"
        ((i++))
    done
    echo ""
    read -r -p "  ${RED}›${NC} Número: " sel
    if [[ -n "${pnames[$sel]:-}" ]]; then
        _selected="${pnames[$sel]}"
        return 0
    fi
    return 1
}

# ═══════════════════════════════════════════════════════════════
#  --list
# ═══════════════════════════════════════════════════════════════

cmd_list() {
    list_profiles
}

# ═══════════════════════════════════════════════════════════════
#  --clone
# ═══════════════════════════════════════════════════════════════

cmd_clone() {
    local source="$1" dest="$2"

    validate_profile "$source"

    if profile_exists "$dest"; then
        die "El perfil destino '${dest}' ya existe. Usa otro nombre o elimínalo primero."
    fi

    header "🔥 Clonando perfil: ${source} → ${dest}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${YELLOW}⏻${NC} Dry-run: se simulará la clonación sin efectos reales"
        echo ""
    fi

    if [[ "$DRY_RUN" != true ]]; then
        mkdir -p "${PROFILES_DIR}/${dest}"
    fi

    # Directorios esenciales a clonar
    local clone_dirs=(
        "skills"
        "memories"
        "cron"
        "hooks"
        "plans"
        "workspace"
        "home"
        "bin"
        "cache"
        "sessions"
        "pairing"
        "skins"
        "audio_cache"
        "image_cache"
        "logs"
    )

    # Archivos bloqueados que NO se copian (Hermes los regenera)
    local locked_files=(
        "auth.lock"
        "state.db-shm"
        "state.db-wal"
    )

    local cloned_count=0
    for dir in "${clone_dirs[@]}"; do
        if [[ -d "${PROFILES_DIR}/${source}/${dir}" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                local dir_size
                dir_size=$(du -sh "${PROFILES_DIR}/${source}/${dir}" 2>/dev/null | cut -f1)
                echo -e "  ${GRAY}⏻${NC} ${GRAY}${dir}${NC}  (${dir_size})"
                ((cloned_count++))
            else
                cp -r "${PROFILES_DIR}/${source}/${dir}" "${PROFILES_DIR}/${dest}/${dir}" 2>/dev/null && {
                    echo -e "  ${CHECK} ${GRAY}${dir}${NC}"
                    ((cloned_count++))
                } || {
                    warn "No se pudo clonar ${dir}"
                }
            fi
        fi
    done

    # Archivos esenciales
    local clone_files=(
        "config.yaml"
        "SOUL.md"
        "auth.json"
        ".env"
    )

    local file_count=0
    for file in "${clone_files[@]}"; do
        if [[ -f "${PROFILES_DIR}/${source}/${file}" ]]; then
            # Saltar archivos bloqueados
            local is_locked=false
            for lf in "${locked_files[@]}"; do
                if [[ "$file" == "$lf" ]]; then
                    is_locked=true
                    break
                fi
            done
            if [[ "$is_locked" == true ]]; then
                echo -e "  ${YELLOW}⛌${NC} ${GRAY}${file}${NC}  (bloqueado, se omite)"
                continue
            fi

            if [[ "$DRY_RUN" == true ]]; then
                echo -e "  ${GRAY}⏻${NC} ${GRAY}${file}${NC}"
                ((file_count++))
            else
                cp "${PROFILES_DIR}/${source}/${file}" "${PROFILES_DIR}/${dest}/${file}" 2>/dev/null && {
                    echo -e "  ${CHECK} ${GRAY}${file}${NC}"
                    ((file_count++))
                }
            fi
        fi
    done

    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Se clonarían ${cloned_count} directorios y ${file_count} archivos desde '${source}' → '${dest}'"
        log "[DRY-RUN] Usa --dry-run para simular, quítalo para ejecutar"
    else
        log "Perfil '${dest}' creado exitosamente"
        log "${cloned_count} directorios y ${file_count} archivos clonados desde '${source}'"
        local size
        size=$(du -sh "${PROFILES_DIR}/${dest}" 2>/dev/null | cut -f1)
        log "Tamaño total: ${size}"
    fi
}

# ═══════════════════════════════════════════════════════════════
#  --diff
# ═══════════════════════════════════════════════════════════════

cmd_diff() {
    local profile_a="$1" profile_b="$2"

    validate_profile "$profile_a"
    validate_profile "$profile_b"

    header "🔍 Comparando: ${profile_a} ↔ ${profile_b}"

    # 1. Comparar config.yaml
    if [[ -f "${PROFILES_DIR}/${profile_a}/config.yaml" && -f "${PROFILES_DIR}/${profile_b}/config.yaml" ]]; then
        echo -e "  ${BOLD}📄 config.yaml${NC}"
        local diff_out
        diff_out=$(diff -u \
            "${PROFILES_DIR}/${profile_a}/config.yaml" \
            "${PROFILES_DIR}/${profile_b}/config.yaml" 2>/dev/null | head -40) || true
        if [[ -z "$diff_out" ]]; then
            echo -e "    ${CHECK} Idénticos"
        else
            echo -e "    ${YELLOW}⚠ Diferencias encontradas:${NC}"
            echo "$diff_out" | while IFS= read -r line; do
                echo -e "    ${GRAY}$line${NC}"
            done
        fi
    else
        echo -e "  ${GRAY}│${NC}  ${YELLOW}⚠${NC} config.yaml no presente en uno o ambos perfiles"
    fi
    echo ""

    # 2. Comparar skills
    echo -e "  ${BOLD}🧰 Skills${NC}"
    local skills_a=() skills_b=()
    if [[ -d "${PROFILES_DIR}/${profile_a}/skills" ]]; then
        while IFS= read -r f; do
            skills_a+=("$(basename "$f")")
        done < <(find "${PROFILES_DIR}/${profile_a}/skills" -maxdepth 1 -type d 2>/dev/null | sort | tail -n +2)
    fi
    if [[ -d "${PROFILES_DIR}/${profile_b}/skills" ]]; then
        while IFS= read -r f; do
            skills_b+=("$(basename "$f")")
        done < <(find "${PROFILES_DIR}/${profile_b}/skills" -maxdepth 1 -type d 2>/dev/null | sort | tail -n +2)
    fi

    local in_a_not_b=()
    local in_b_not_a=()
    local common=()

    for skill in "${skills_a[@]}"; do
        if [[ " ${skills_b[*]} " =~ ${skill}  ]]; then
            common+=("$skill")
        else
            in_a_not_b+=("$skill")
        fi
    done
    for skill in "${skills_b[@]}"; do
        if ! [[ " ${skills_a[*]} " =~ ${skill}  ]]; then
            in_b_not_a+=("$skill")
        fi
    done

    echo -e "    ${BLUE}🧠${NC} Comunes: ${BOLD}${#common[@]}${NC}"
    echo -e "    ${GREEN}+${NC} Solo en ${profile_a}: ${BOLD}${#in_a_not_b[@]}${NC}"
    for s in "${in_a_not_b[@]}"; do
        echo -e "      ${GREEN}+${NC} $s"
    done
    echo -e "    ${RED}-${NC} Solo en ${profile_b}: ${BOLD}${#in_b_not_a[@]}${NC}"
    for s in "${in_b_not_a[@]}"; do
        echo -e "      ${RED}-${NC} $s"
    done
    echo ""

    # 3. Comparar SOUL.md
    echo -e "  ${BOLD}📜 SOUL.md${NC}"
    if [[ -f "${PROFILES_DIR}/${profile_a}/SOUL.md" && -f "${PROFILES_DIR}/${profile_b}/SOUL.md" ]]; then
        local soul_diff
        soul_diff=$(diff -u \
            "${PROFILES_DIR}/${profile_a}/SOUL.md" \
            "${PROFILES_DIR}/${profile_b}/SOUL.md" 2>/dev/null | head -30) || true
        if [[ -z "$soul_diff" ]]; then
            echo -e "    ${CHECK} Idénticos"
        else
            echo -e "    ${YELLOW}⚠ Diferencias:${NC}"
            echo "$soul_diff" | while IFS= read -r line; do
                echo -e "    ${GRAY}$line${NC}"
            done
        fi
    else
        echo -e "    ${YELLOW}⚠ SOUL.md no presente en uno o ambos perfiles${NC}"
    fi
    echo ""

    # 4. Resumen de memorias
    echo -e "  ${BOLD}🧠 Memorias${NC}"
    local mem_a=0 mem_b=0
    if [[ -d "${PROFILES_DIR}/${profile_a}/memories" ]]; then
        mem_a=$(find "${PROFILES_DIR}/${profile_a}/memories" -type f 2>/dev/null | wc -l)
    fi
    if [[ -d "${PROFILES_DIR}/${profile_b}/memories" ]]; then
        mem_b=$(find "${PROFILES_DIR}/${profile_b}/memories" -type f 2>/dev/null | wc -l)
    fi
    echo -e "    ${profile_a}: ${BOLD}${mem_a}${NC} archivos"
    echo -e "    ${profile_b}: ${BOLD}${mem_b}${NC} archivos"
    if [[ "$mem_a" -ne "$mem_b" ]]; then
        echo -e "    ${YELLOW}⚠ Diferencia de $((mem_a > mem_b ? mem_a - mem_b : mem_b - mem_a)) archivos${NC}"
    fi
    echo ""

    # 5. Resumen general
    echo -e "  ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}Resumen:${NC}"
    echo -e "  · Skills compartidas: ${BOLD}${#common[@]}${NC}"
    echo -e "  · Skills exclusivas ${profile_a}: ${BOLD}${#in_a_not_b[@]}${NC}"
    echo -e "  · Skills exclusivas ${profile_b}: ${BOLD}${#in_b_not_a[@]}${NC}"
    echo -e "  · Memorias ${profile_a}: ${BOLD}${mem_a}${NC} · Memorias ${profile_b}: ${BOLD}${mem_b}${NC}"
}

# ═══════════════════════════════════════════════════════════════
#  --backup
# ═══════════════════════════════════════════════════════════════

cmd_backup() {
    local profile="$1"

    validate_profile "$profile"

    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local backup_name="forge-${profile}-${ts}"
    local backup_path="${FORGE_BACKUP_DIR}/${backup_name}"

    header "💾 Creando backup de: ${profile}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${YELLOW}⏻${NC} Dry-run: se simulará el backup sin efectos reales"
        echo ""
    fi

    echo -e "  ${GRAY}│${NC}  Perfil:  ${BOLD}${profile}${NC}"
    echo -e "  ${GRAY}│${NC}  Fecha:   ${ts}"
    echo -e "  ${GRAY}│${NC}  Destino: ${GRAY}${backup_path}${NC}"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        local profile_size
        profile_size=$(du -sh "${PROFILES_DIR}/${profile}" 2>/dev/null | cut -f1)
        echo -e "  ${GRAY}⏻${NC} Se respaldaría: ${BOLD}${profile}${NC} (${profile_size})"
        log "[DRY-RUN] Backup simulado correctamente"
        log "[DRY-RUN] Quita --dry-run para ejecutar el backup real"
        return 0
    fi

    mkdir -p "$backup_path"

    # Backup completo del perfil
    cp -r "${PROFILES_DIR}/${profile}/." "${backup_path}/" 2>/dev/null || {
        warn "Algunos archivos no pudieron copiarse"
    }

    local total_size
    total_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)

    echo -e "  ${CHECK} Backup completo: ${GRAY}${backup_path}${NC}"
    log "Tamaño: ${total_size}"
    log "Backup creado exitosamente (ID: ${backup_name})"

    # Cleanup automático: mantener solo los últimos 5 backups del mismo perfil
    local old_backups=()
    while IFS= read -r b; do
        old_backups+=("$b")
    done < <(find "$FORGE_BACKUP_DIR" -maxdepth 1 -type d -name "forge-${profile}-*" | sort | head -n -5)

    if [[ ${#old_backups[@]} -gt 0 ]]; then
        echo ""
        for old in "${old_backups[@]}"; do
            rm -rf "$old"
            dim "  Backup antiguo eliminado: $(basename "$old")"
        done
        dim "  (Máximo 5 backups por perfil mantenidos automáticamente)"
    fi
}

# ═══════════════════════════════════════════════════════════════
#  HEALTH — Auditoría de todos los perfiles
# ═══════════════════════════════════════════════════════════════

cmd_health() {
    header "🩺 ignisky-forge:health — Auditoría de perfiles"
    echo ""

    local profiles=()
    while IFS= read -r p; do
        local name
        name=$(basename "$p")
        [[ "$name" == "$(basename "$PROFILES_DIR")" ]] && continue
        profiles+=("$name")
    done < <(find "$PROFILES_DIR" -maxdepth 1 -type d 2>/dev/null | sort)

    # Incluir perfil default (config.yaml raíz)
    profiles+=("(default)")

    if [[ ${#profiles[@]} -eq 0 ]]; then
        warn "No se encontraron perfiles en ${PROFILES_DIR}"
        return 1
    fi

    echo -e "  ${BOLD}Analizando ${#profiles[@]} perfiles...${NC}\n"
    echo -e "  ${GRAY}┌────────────────────────────────────────────────────────────────┐${NC}"

    for profile in "${profiles[@]}"; do
        if [[ "$profile" == "(default)" ]]; then
            analyze_profile "default" "$HERMES_HOME"
        else
            analyze_profile "$profile" "${PROFILES_DIR}/${profile}"
        fi
    done

    echo -e "  ${GRAY}└────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    log "Health check completado"
}

analyze_profile() {
    local name="$1" path="$2"
    local cfg_file="${path}/config.yaml"
    local score=100
    local issues=()

    # 1. Config existe
    if [[ ! -f "$cfg_file" ]]; then
        score=$((score - 40))
        issues+=("No config.yaml")
    fi

    # 2. Tamaño en disco
    local size
    size=$(du -sh "$path" 2>/dev/null | cut -f1)
    local size_bytes
    size_bytes=$(du -sb "$path" 2>/dev/null | cut -f1)
    if [[ $size_bytes -gt 104857600 ]]; then
        score=$((score - 15))
        issues+=(">100MB — logs grandes?")
    fi

    # 3. MCPs instalados
    local mcp_count=0
    if [[ -f "$cfg_file" ]]; then
        mcp_count=$(python3 -c "
import yaml, json, sys
try:
    with open('${cfg_file}') as f:
        cfg = yaml.safe_load(f)
    mcps = cfg.get('mcp_servers', {})
    print(len(mcps))
except:
    print(0)
" 2>/dev/null || echo 0)
    fi
    if [[ "$mcp_count" -eq 0 ]]; then
        score=$((score - 10))
        issues+=("Sin MCPs configurados")
    fi

    # 4. Skills instaladas
    local skill_count=0
    local skills_dir="${path}/skills"
    if [[ -d "$skills_dir" ]]; then
        skill_count=$(find "$skills_dir" -name "SKILL.md" 2>/dev/null | wc -l)
    fi

    # 5. Modelo configurado
    local model=""
    if [[ -f "$cfg_file" ]]; then
        model=$(python3 -c "
import yaml
try:
    with open('${cfg_file}') as f:
        cfg = yaml.safe_load(f)
    print(cfg.get('model', {}).get('default', 'sin modelo'))
except:
    print('Error al leer')
" 2>/dev/null)
    fi

    # 6. Token efficiency (si se puede leer config)
    local token_score=0
    if [[ -f "$cfg_file" ]]; then
        token_score=$(python3 -c "
import yaml
try:
    with open('${cfg_file}') as f:
        cfg = yaml.safe_load(f)
    s = 0
    a = cfg.get('agent', {})
    c = cfg.get('compression', {})
    if a.get('reasoning_effort') == 'low': s += 25
    elif a.get('reasoning_effort') == 'medium': s += 15
    if c.get('enabled'): s += 25
    mt = a.get('max_turns', 60)
    if mt <= 60: s += 15
    elif mt <= 90: s += 10
    print(s)
except:
    print(0)
" 2>/dev/null)
    fi

    # Grade
    local grade="A"
    if [[ "$score" -ge 90 ]]; then grade="A"
    elif [[ "$score" -ge 75 ]]; then grade="B"
    elif [[ "$score" -ge 50 ]]; then grade="C"
    else grade="D"
    fi

    # Color según grade
    local grade_color="${GREEN}"
    if [[ "$grade" == "B" ]]; then grade_color="${YELLOW}"
    elif [[ "$grade" == "C" || "$grade" == "D" ]]; then grade_color="${RED}"
    fi

    # Output resumido
    local icon="🟢"
    [[ "$grade" == "B" ]] && icon="🟡"
    [[ "$grade" == "C" ]] && icon="🟠"
    [[ "$grade" == "D" ]] && icon="🔴"

    echo -e "  ${GRAY}│${NC}"
    echo -e "  ${GRAY}│${NC}  ${icon} ${BOLD}$name${NC}"
    echo -e "  ${GRAY}│${NC}  📦 Tamaño:   ${size}"
    echo -e "  ${GRAY}│${NC}  ⚙️  Modelo:   ${model}"
    echo -e "  ${GRAY}│${NC}  📎 MCPs:     ${mcp_count}"
    echo -e "  ${GRAY}│${NC}  🧠 Skills:   ${skill_count}"
    echo -e "  ${GRAY}│${NC}  ⚡ Tokens:   ${token_score}/65"
    echo -e "  ${GRAY}│${NC}  ${grade_color}${BOLD}NOTA: ${score}/100 (${grade})${NC}"

    if [[ ${#issues[@]} -gt 0 ]]; then
        for issue in "${issues[@]}"; do
            echo -e "  ${GRAY}│${NC}  ${YELLOW}⚠️  ${issue}${NC}"
        done
    fi
}

# ═══════════════════════════════════════════════════════════════
#  FUNCIONES PREMIUM (stubs con cupón)
# ═══════════════════════════════════════════════════════════════

premium_show_header() {
    local feature="$1"
    header "🔥 ignisky-forge:${feature}"
    echo -e "  ${YELLOW}⛁${NC} ${BOLD}Premium feature${NC}"
}

premium_footer() {
    echo ""
    echo -e "  ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}💎 Esta función está disponible en el pack premium${NC}"
    echo -e "  ${BOLD}👉 https://ignaciodev.gumroad.com/l/lpyqm  ·  Cupón: ${RED}IGNICION25${NC}"
    echo -e "  ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

premium_merge() {
    local profile_a="$1" profile_b="$2"
    if [[ -z "$profile_a" || -z "$profile_b" ]]; then
        die "Uso: --merge <perfil-a> <perfil-b>"
    fi

    premium_show_header "forge:fuse — Smart Merge"
    echo -e "  ${BOLD}Fusiona config.yaml de dos perfiles conservando settings de ambos:${NC}"
    echo ""
    echo -e "  ${GRAY}│${NC}  🅰️  ${BOLD}$profile_a${NC}  ${GRAY}+${NC}  🅱️  ${BOLD}$profile_b${NC}"
    echo ""
    dim "  · Compara secciones de config.yaml línea por línea"
    dim "  · Detecta conflictos en mcp_servers, skills, providers"
    dim "  · Conserva ambos valores cuando hay duplicados"
    dim "  · Genera un output unificado listo para usar"
    echo ""
    dim "  Ejemplo: combina MCPs de perfil A con settings de perfil B"
    premium_footer
}

premium_sync() {
    local from="$1" to="$2"
    if [[ -z "$from" || -z "$to" ]]; then
        die "Uso: --sync <desde> <hacia>"
    fi

    premium_show_header "forge:sync — Sincronización de Skills"
    echo -e "  ${BOLD}Sincroniza skills de un perfil a otro resolviendo conflictos:${NC}"
    echo ""
    echo -e "  ${GRAY}│${NC}  📤 ${BOLD}$from${NC}  ${GRAY}→${NC}  📥 ${BOLD}$to${NC}"
    echo ""
    dim "  · Copia skills faltantes del origen al destino"
    dim "  · Detecta skills con mismo nombre pero distinto contenido"
    dim "  · Ofrece resolución manual o automática de conflictos"
    dim "  · Modo dry-run disponible para previsualizar cambios"
    echo ""
    dim "  Ideal para mantener skills consistentes entre perfiles"
    premium_footer
}

premium_migrate() {
    local from="$1" to="$2"
    if [[ -z "$from" || -z "$to" ]]; then
        die "Uso: --migrate-engram <desde> <hacia>"
    fi

    premium_show_header "forge:migrate — Migración de Engram (Memorias)"
    echo -e "  ${BOLD}Migra la base de datos de memorias entre perfiles:${NC}"
    echo ""
    echo -e "  ${GRAY}│${NC}  🧠 ${BOLD}$from${NC}  ${GRAY}→${NC}  🧠 ${BOLD}$to${NC}"
    echo ""
    dim "  · Migra state.db (SQLite/FTS5) de un perfil a otro"
    dim "  · Preserva integridad referencial de la base de datos"
    dim "  · Modo append: agrega sin sobrescribir existentes"
    dim "  · Backup automático antes de la migración"
    echo ""
    dim "  Transfiere el conocimiento de tu agente entre perfiles"
    premium_footer
}

premium_scheduler() {
    local profile="$1"
    if [[ -z "$profile" ]]; then
        die "Uso: --schedule <perfil>"
    fi

    premium_show_header "forge:scheduler — Backup Automático"
    echo -e "  ${BOLD}Programa backups automáticos con cron:${NC}"
    echo ""
    echo -e "  ${GRAY}│${NC}  📅 Perfil: ${BOLD}$profile${NC}"
    echo ""
    dim "  · Crea tarea cron para backup diario/semanal/mensual"
    dim "  · Rotación automática de backups antiguos"
    dim "  · Notificaciones al completar el backup"
    dim "  · Se integra con el sistema de cron de Hermes"
    echo ""
    dim "  Tu perfil siempre seguro con backups automáticos"
    premium_footer
}

premium_snapshot() {
    premium_show_header "forge:snap — Restore Point"
    echo -e "  ${BOLD}Crea un restore point con timestamp de TODO tu estado:${NC}"
    echo ""
    echo -e "  ${GRAY}│${NC}  📸 Snapshot completo del ecosistema Hermes"
    echo ""
    dim "  · Captura todos los perfiles en un punto en el tiempo"
    dim "  · Incluye config, skills, memorias, y estado actual"
    dim "  · Permite rollback completo a cualquier snapshot"
    dim "  · Ideal antes de cambios masivos o actualizaciones"
    echo ""
    dim "  Tu red de seguridad definitiva para Hermes Agent"
    premium_footer
}

# ═══════════════════════════════════════════════════════════════
#  MODO INTERACTIVO
# ═══════════════════════════════════════════════════════════════

show_banner() {
    echo ""
    echo -e "  ${RED}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "  ${RED}${BOLD}║   🔥 ignisky-forge v${VERSION}               ${NC}"
    echo -e "  ${RED}${BOLD}║   La forja de tus perfiles Hermes       ║${NC}"
    echo -e "  ${RED}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GRAY}by IgnicionDev · Parte de ignisky-* 🔥${NC}"
    echo ""
}

show_status() {
    echo -e "  ${RED}${BOLD}═══ 📊 Estado ═══${NC}"
    echo ""

    local profiles=()
    get_profile_list profiles

    if command -v hermes &>/dev/null; then
        echo -e "  ${CHECK} Hermes: ${BOLD}$(hermes --version 2>&1 | head -1)${NC}"
    else
        echo -e "  ${CROSS} Hermes CLI no encontrado"
    fi
    echo -e "  ${CHECK} Perfiles: ${BOLD}${#profiles[@]}${NC}"
    echo -e "  ${CHECK} Directorio: ${GRAY}${PROFILES_DIR}${NC}"
    echo -e "  ${CHECK} Backups: ${GRAY}${FORGE_BACKUP_DIR}${NC}"
    echo ""
}

interactive_menu() {
    while true; do
        echo -e "\n${RED}${BOLD}┌─ ¿Qué quieres hacer en la forja? ─────────────────────┐${NC}"
        echo -e "  ${GRAY}│${NC}  ${BOLD}1${NC}  📋  Listar perfiles disponibles"
        echo -e "  ${GRAY}│${NC}  ${BOLD}2${NC}  🔄  Clonar un perfil"
        echo -e "  ${GRAY}│${NC}  ${BOLD}3${NC}  🔍  Comparar dos perfiles (diff)"
        echo -e "  ${GRAY}│${NC}  ${BOLD}4${NC}  💾  Hacer backup de un perfil"
        echo -e "  ${GRAY}│${NC}  ${BOLD}5${NC}  🩺  Health check de todos los perfiles"
        echo -e "  ${GRAY}│${NC}  ${BOLD}6${NC}  🧬  Fusionar configs (Premium)"
        echo -e "  ${GRAY}│${NC}  ${BOLD}7${NC}  📤  Sincronizar skills (Premium)"
        echo -e "  ${GRAY}│${NC}  ${BOLD}8${NC}  🧠  Migrar memorias (Premium)"
        echo -e "  ${GRAY}│${NC}  ${BOLD}9${NC}  💎  Ver funciones premium"
        echo -e "  ${GRAY}│${NC}  ${BOLD}0${NC}  🚪  Salir"
        echo -e "${RED}${BOLD}└────────────────────────────────────────────────────────┘${NC}"
        echo ""
        read -r -p "  ${RED}›${NC} ${BOLD}Opción${NC} [0-9]: " opt
        echo ""

        case "$opt" in
            1)
                list_profiles
                echo ""
                read -r -p "  ${RED}›${NC} Presiona Enter para continuar..." _
                ;;
            2)
                local src=""
                select_profile "Selecciona el perfil ORIGEN:" src || { warn "Selección cancelada"; continue; }
                echo ""
                read -r -p "  ${RED}›${NC} Nombre del perfil DESTINO: " dest
                if [[ -z "$dest" ]]; then
                    warn "Nombre inválido"
                    continue
                fi
                cmd_clone "$src" "$dest"
                echo ""
                read -r -p "  ${RED}›${NC} Presiona Enter para continuar..." _
                ;;
            3)
                local a="" b=""
                select_profile "Selecciona el PRIMER perfil:" a || { warn "Selección cancelada"; continue; }
                echo ""
                select_profile "Selecciona el SEGUNDO perfil:" b || { warn "Selección cancelada"; continue; }
                cmd_diff "$a" "$b"
                echo ""
                read -r -p "  ${RED}›${NC} Presiona Enter para continuar..." _
                ;;
            4)
                local bp=""
                select_profile "Selecciona el perfil a respaldar:" bp || { warn "Selección cancelada"; continue; }
                cmd_backup "$bp"
                echo ""
                read -r -p "  ${RED}›${NC} Presiona Enter para continuar..." _
                ;;
            5)
                cmd_health
                echo ""
                read -r -p "  ${RED}›${NC} Presiona Enter para continuar..." _
                ;;
            6)
                local ma="" mb=""
                select_profile "Selecciona el PRIMER perfil para fusionar:" ma || { warn "Selección cancelada"; continue; }
                echo ""
                select_profile "Selecciona el SEGUNDO perfil para fusionar:" mb || { warn "Selección cancelada"; continue; }
                premium_merge "$ma" "$mb"
                echo ""
                read -r -p "  ${RED}›${NC} Presiona Enter para continuar..." _
                ;;
            7)
                local sf="" st=""
                select_profile "Selecciona el perfil ORIGEN (skills a copiar):" sf || { warn "Selección cancelada"; continue; }
                echo ""
                select_profile "Selecciona el perfil DESTINO:" st || { warn "Selección cancelada"; continue; }
                premium_sync "$sf" "$st"
                echo ""
                read -r -p "  ${RED}›${NC} Presiona Enter para continuar..." _
                ;;
            8)
                local mf="" mt=""
                select_profile "Selecciona el perfil ORIGEN (memorias a migrar):" mf || { warn "Selección cancelada"; continue; }
                echo ""
                select_profile "Selecciona el perfil DESTINO:" mt || { warn "Selección cancelada"; continue; }
                premium_migrate "$mf" "$mt"
                echo ""
                read -r -p "  ${RED}›${NC} Presiona Enter para continuar..." _
                ;;
            9)
                header "💎 ignisky-forge Premium"
                echo -e "  ${BOLD}Funciones exclusivas de la forja:${NC}"
                echo ""
                echo -e "  ${GRAY}│${NC}  🧬  ${BOLD}forge:fuse${NC}      ${GRAY}· Smart Merge de config.yaml entre perfiles${NC}"
                echo -e "  ${GRAY}│${NC}  📤  ${BOLD}forge:sync${NC}      ${GRAY}· Sincroniza skills resolviendo conflictos${NC}"
                echo -e "  ${GRAY}│${NC}  🧠  ${BOLD}forge:migrate${NC}   ${GRAY}· Migra memorias (SQLite/FTS5) entre perfiles${NC}"
                echo -e "  ${GRAY}│${NC}  📅  ${BOLD}forge:scheduler${NC} ${GRAY}· Programa backups automáticos con cron${NC}"
                echo -e "  ${GRAY}│${NC}  📸  ${BOLD}forge:snap${NC}      ${GRAY}· Restore point completo con timestamp${NC}"
                echo ""
                echo -e "  ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "  ${BOLD}👉 https://ignaciodev.gumroad.com/l/lpyqm${NC}"
                echo -e "  ${BOLD}🏷️  Cupón: ${RED}IGNICION25${NC} ${GRAY}(25% OFF → 11.25€)${NC}"
                echo -e "  ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""
                read -r -p "  ${RED}›${NC} Presiona Enter para volver al menú..." _
                ;;
            0)
                echo -e "  ${GREEN}¡Hasta luego! Que la forja te acompañe 🔥${NC}\n"
                exit 0
                ;;
            *)
                warn "Opción inválida [0-9]"
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
#  PARSER DE ARGUMENTOS
# ═══════════════════════════════════════════════════════════════

usage() {
    echo -e "${RED}${BOLD}ignisky-forge v${VERSION}${NC} ${GRAY}— La forja de tus perfiles Hermes 🔥${NC}"
    echo ""
    echo -e "${BOLD}Uso:${NC} ${SCRIPT_NAME} [opciones]"
    echo ""
    echo -e "${BOLD}Opciones gratuitas:${NC}"
    echo -e "  ${GREEN}--help${NC}, ${GREEN}-h${NC}              Muestra esta ayuda"
    echo -e "  ${GREEN}--version${NC}                  Muestra la versión"
    echo -e "  ${GREEN}--list${NC}                     Lista todos los perfiles Hermes disponibles"
    echo -e "  ${GREEN}--clone${NC} <origen> <dest>    Clona estructura de directorios entre perfiles"
    echo -e "  ${GREEN}--diff${NC} <a> <b>             Muestra diferencias entre dos perfiles"
    echo -e "  ${GREEN}--backup${NC} <perfil>          Crea backup del perfil en ~/.hermes/backups/"
    echo -e "  ${GREEN}--health${NC}                Auditoría de todos los perfiles (nota A-F)"
    echo -e "  ${GREEN}--silent${NC}                   Sin output interactivo (modo script)"
    echo ""
    echo -e "${BOLD}Premium (requiere pack con cupón ${RED}IGNICION25${NC}${BOLD}):${NC}"
    echo -e "  ${YELLOW}⛁${NC} ${GREEN}--merge${NC} <a> <b>           Smart Merge: fusiona config.yaml de 2 perfiles"
    echo -e "  ${YELLOW}⛁${NC} ${GREEN}--sync${NC} <from> <to>        Sincroniza skills de un perfil a otro"
    echo -e "  ${YELLOW}⛁${NC} ${GREEN}--migrate-engram${NC} <f> <t>  Migra memorias entre perfiles (SQLite/FTS5)"
    echo -e "  ${YELLOW}⛁${NC} ${GREEN}--schedule${NC} <perfil>       Programa backups automáticos con cron"
    echo -e "  ${YELLOW}⛁${NC} ${GREEN}--snapshot${NC}                Crea restore point con timestamp"
    echo ""
    echo -e "${BOLD}Ejemplos:${NC}"
    echo -e "  ${GRAY}# Modo interactivo (por defecto)${NC}"
    echo -e "  ${SCRIPT_NAME}"
    echo ""
    echo -e "  ${GRAY}# Listar perfiles${NC}"
    echo -e "  ${SCRIPT_NAME} --list"
    echo ""
    echo -e "  ${GRAY}# Clonar un perfil${NC}"
    echo -e "  ${SCRIPT_NAME} --clone profile-laguna1-v1 profile-nuevo"
    echo ""
    echo -e "  ${GRAY}# Comparar dos perfiles${NC}"
    echo -e "  ${SCRIPT_NAME} --diff profile-a profile-b"
    echo ""
    echo -e "  ${GRAY}# Backup de un perfil${NC}"
    echo -e "  ${SCRIPT_NAME} --backup profile-laguna1-v1"
    echo ""
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}💎 https://ignaciodev.gumroad.com/l/lpyqm  ·  Cupón: ${RED}IGNICION25${NC}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
}

VERBOSE=false
DRY_RUN=false
SILENT=false
INTERACTIVE=true

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)          usage ;;
            --version)          echo "ignisky-forge v${VERSION}"; exit 0 ;;
            -v|--verbose)       VERBOSE=true ;;
            --dry-run)          DRY_RUN=true ;;
            --silent)           SILENT=true; INTERACTIVE=false ;;
            --list)             MODE="list" ;;
            --clone)            MODE="clone"; CLONE_SRC="$2"; CLONE_DST="$3"; shift 2 ;;
            --diff)             MODE="diff"; DIFF_A="$2"; DIFF_B="$3"; shift 2 ;;
            --backup)           MODE="backup"; BACKUP_PROFILE="$2"; shift ;;
            --merge)            MODE="merge"; MERGE_A="$2"; MERGE_B="$3"; shift 2 ;;
            --sync)             MODE="sync"; SYNC_FROM="$2"; SYNC_TO="$3"; shift 2 ;;
            --migrate-engram)   MODE="migrate"; MIGRATE_FROM="$2"; MIGRATE_TO="$3"; shift 2 ;;
            --schedule)         MODE="schedule"; SCHEDULE_PROFILE="$2"; shift ;;
            --snapshot)         MODE="snapshot" ;;
            --health)           MODE="health" ;;
            *)                  die "Opción desconocida: $1. Usa --help para ayuda." ;;
        esac
        shift
    done
}

# ═══════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════

main() {
    parse_args "$@"

    # Si hay modo específico por flag, ejecutar y salir
    if [[ -n "${MODE:-}" ]]; then
        case "$MODE" in
            list)
                detect_hermes || exit 1
                cmd_list
                ;;
            clone)
                detect_hermes || exit 1
                if [[ -z "${CLONE_SRC:-}" || -z "${CLONE_DST:-}" ]]; then
                    die "Uso: --clone <origen> <destino>"
                fi
                cmd_clone "$CLONE_SRC" "$CLONE_DST"
                ;;
            diff)
                detect_hermes || exit 1
                if [[ -z "${DIFF_A:-}" || -z "${DIFF_B:-}" ]]; then
                    die "Uso: --diff <perfil-a> <perfil-b>"
                fi
                cmd_diff "$DIFF_A" "$DIFF_B"
                ;;
            backup)
                detect_hermes || exit 1
                if [[ -z "${BACKUP_PROFILE:-}" ]]; then
                    die "Uso: --backup <perfil>"
                fi
                cmd_backup "$BACKUP_PROFILE"
                ;;
            merge)
                premium_merge "${MERGE_A:-}" "${MERGE_B:-}"
                ;;
            sync)
                premium_sync "${SYNC_FROM:-}" "${SYNC_TO:-}"
                ;;
            migrate)
                premium_migrate "${MIGRATE_FROM:-}" "${MIGRATE_TO:-}"
                ;;
            schedule)
                premium_scheduler "${SCHEDULE_PROFILE:-}"
                ;;
            snapshot)
                premium_snapshot
                ;;
            health)
                detect_hermes || exit 1
                cmd_health
                ;;
        esac
        exit 0
    fi

    # Modo interactivo (por defecto)
    detect_hermes || exit 1

    show_banner
    show_status

    if [[ "$DRY_RUN" == true ]]; then
        warn "Modo dry-run activado — solo se mostrará información, sin cambios"
        echo ""
    fi

    interactive_menu
}

main "$@"
