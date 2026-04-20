#!/usr/bin/env bash
# =============================================================================
# wpclone — WordPress Site Migration Tool
# Version: 1.0.0
# License: MIT
#
# Usage:
#   wpclone [OPTIONS]
#
# Examples:
#   wpclone --src-host user@old-server.com --src-path /var/www/html \
#           --dst-host user@new-server.com --dst-path /var/www/html \
#           --old-url https://old-site.com --new-url https://new-site.com
#
#   wpclone --config migration.conf
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────────────────────
# Constants & Defaults
# ─────────────────────────────────────────────────────────────────────────────
readonly WPCLONE_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly TMP_DIR="/tmp/wpclone_$$"
readonly LOG_FILE="${WPCLONE_LOG:-./wpclone.log}"

# Colors — use $'...' so bash interprets \033 as an actual ESC byte.
# Disabled automatically when stdout is not a TTY (pipes, redirects, etc.)
if [ -t 1 ]; then
  RED=$'\033[0;31m'   YELLOW=$'\033[1;33m'  GREEN=$'\033[0;32m'
  CYAN=$'\033[0;36m'  BOLD=$'\033[1m'        DIM=$'\033[2m'    RESET=$'\033[0m'
else
  RED='' YELLOW='' GREEN='' CYAN='' BOLD='' DIM='' RESET=''
fi

# ─────────────────────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────────────────────
_log() {
  local level="$1"; shift
  local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
  printf "[%s] [%-5s] %s\n" "$ts" "$level" "$*" >> "$LOG_FILE"
}

info()    { printf '%s[INFO]%s  %s\n'  "$CYAN"   "$RESET" "$*"; _log INFO  "$*"; }
success() { printf '%s[OK]%s    %s\n'  "$GREEN"  "$RESET" "$*"; _log OK    "$*"; }
warn()    { printf '%s[WARN]%s  %s\n'  "$YELLOW" "$RESET" "$*"; _log WARN  "$*"; }
error()   { printf '%s[ERROR]%s %s\n'  "$RED"    "$RESET" "$*" >&2; _log ERROR "$*"; }
fatal()   { error "$*"; cleanup; exit 1; }
step()    { printf '\n%s%s▶ %s%s\n' "$BOLD" "$CYAN" "$*" "$RESET"; _log STEP  "$*"; }
debug()   {
  [[ "${WPCLONE_DEBUG:-0}" == "1" ]] && printf '%s[DEBUG] %s%s\n' "$DIM" "$*" "$RESET"
  _log DEBUG "$*"
}

# ─────────────────────────────────────────────────────────────────────────────
# Help / Usage
# ─────────────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}wpclone v${WPCLONE_VERSION}${RESET} — WordPress Site Migration Tool

${BOLD}USAGE:${RESET}
  $SCRIPT_NAME [OPTIONS]
  $SCRIPT_NAME --config <file>

${BOLD}REQUIRED (unless --config is used):${RESET}
  --src-host   <user@host>    SSH connection string for the source server
  --src-path   <path>         Absolute path to WP root on the source server
  --dst-host   <user@host>    SSH connection string for the destination server
  --dst-path   <path>         Absolute path to WP root on the destination server
  --old-url    <url>          Old site URL (e.g. https://old-site.com)
  --new-url    <url>          New site URL (e.g. https://new-site.com)

${BOLD}OPTIONAL:${RESET}
  --config     <file>         Load options from a config file (key=value format)
  --src-port   <port>         SSH port on the source server (default: 22)
  --dst-port   <port>         SSH port on the destination server (default: 22)
  --src-key    <path>         Path to SSH private key for source server
  --dst-key    <path>         Path to SSH private key for destination server
  --db-method  <method>       Database export method: wpcli (default) | mysqldump
  --skip-files                Skip rsync file transfer (DB only)
  --skip-db                   Skip database migration (files only)
  --skip-url-replace          Skip search-and-replace after import
  --exclude    <pattern>      Rsync exclude pattern (repeatable)
  --dry-run                   Simulate without making any changes
  --no-color                  Disable colored output
  --verbose                   Enable verbose rsync output
  --version                   Print version and exit
  -h, --help                  Show this help message

${BOLD}ENVIRONMENT VARIABLES:${RESET}
  WPCLONE_DEBUG=1             Enable debug output
  WPCLONE_LOG=<path>          Override log file path (default: ./wpclone.log)

${BOLD}CONFIG FILE FORMAT:${RESET}
  SRC_HOST=user@old-server.com
  SRC_PATH=/var/www/html
  DST_HOST=user@new-server.com
  DST_PATH=/var/www/html
  OLD_URL=https://old-site.com
  NEW_URL=https://new-site.com
  # Any other option key in UPPER_SNAKE_CASE

${BOLD}EXAMPLES:${RESET}
  # Full migration
  $SCRIPT_NAME \\
    --src-host deploy@old.example.com --src-path /var/www/html \\
    --dst-host deploy@new.example.com --dst-path /var/www/html \\
    --old-url https://old.example.com --new-url https://new.example.com

  # Using a config file
  $SCRIPT_NAME --config production.conf

  # Clone to staging (files + DB, new URL)
  $SCRIPT_NAME --config prod.conf --new-url https://staging.example.com

  # DB only (files already synced)
  $SCRIPT_NAME --config prod.conf --skip-files

  # Dry run
  $SCRIPT_NAME --config prod.conf --dry-run

EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Defaults
# ─────────────────────────────────────────────────────────────────────────────
SRC_HOST=""
SRC_PATH=""
SRC_PORT="22"
SRC_KEY=""
DST_HOST=""
DST_PATH=""
DST_PORT="22"
DST_KEY=""
OLD_URL=""
NEW_URL=""
DB_METHOD="wpcli"
SKIP_FILES=0
SKIP_DB=0
SKIP_URL_REPLACE=0
DRY_RUN=0
VERBOSE=0
EXCLUDES=()

# ─────────────────────────────────────────────────────────────────────────────
# Config File Loader
# ─────────────────────────────────────────────────────────────────────────────
load_config() {
  local cfg="$1"
  [[ -f "$cfg" ]] || fatal "Config file not found: $cfg"
  info "Loading config from: $cfg"
  # shellcheck disable=SC1090
  while IFS='=' read -r key value; do
    # Trim whitespace, skip comments and blank lines
    key="${key//[[:space:]]/}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    [[ -z "$key" || "$key" == \#* ]] && continue

    case "$key" in
      SRC_HOST)       SRC_HOST="$value"       ;;
      SRC_PATH)       SRC_PATH="$value"       ;;
      SRC_PORT)       SRC_PORT="$value"       ;;
      SRC_KEY)        SRC_KEY="$value"        ;;
      DST_HOST)       DST_HOST="$value"       ;;
      DST_PATH)       DST_PATH="$value"       ;;
      DST_PORT)       DST_PORT="$value"       ;;
      DST_KEY)        DST_KEY="$value"        ;;
      OLD_URL)        OLD_URL="$value"        ;;
      NEW_URL)        NEW_URL="$value"        ;;
      DB_METHOD)      DB_METHOD="$value"      ;;
      SKIP_FILES)     SKIP_FILES="$value"     ;;
      SKIP_DB)        SKIP_DB="$value"        ;;
      SKIP_URL_REPLACE) SKIP_URL_REPLACE="$value" ;;
      DRY_RUN)        DRY_RUN="$value"        ;;
      VERBOSE)        VERBOSE="$value"        ;;
      EXCLUDE)        EXCLUDES+=("$value")    ;;
      *)              warn "Unknown config key ignored: $key" ;;
    esac
  done < "$cfg"
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────
parse_args() {
  [[ $# -eq 0 ]] && { usage; exit 0; }

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)       load_config "$2"; shift 2 ;;
      --src-host)     SRC_HOST="$2";   shift 2 ;;
      --src-path)     SRC_PATH="$2";   shift 2 ;;
      --src-port)     SRC_PORT="$2";   shift 2 ;;
      --src-key)      SRC_KEY="$2";    shift 2 ;;
      --dst-host)     DST_HOST="$2";   shift 2 ;;
      --dst-path)     DST_PATH="$2";   shift 2 ;;
      --dst-port)     DST_PORT="$2";   shift 2 ;;
      --dst-key)      DST_KEY="$2";    shift 2 ;;
      --old-url)      OLD_URL="$2";    shift 2 ;;
      --new-url)      NEW_URL="$2";    shift 2 ;;
      --db-method)    DB_METHOD="$2";  shift 2 ;;
      --exclude)      EXCLUDES+=("$2"); shift 2 ;;
      --skip-files)   SKIP_FILES=1;   shift   ;;
      --skip-db)      SKIP_DB=1;      shift   ;;
      --skip-url-replace) SKIP_URL_REPLACE=1; shift ;;
      --dry-run)      DRY_RUN=1;      shift   ;;
      --verbose)      VERBOSE=1;      shift   ;;
      --no-color)
        RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; DIM=''; RESET=''
        shift ;;
      --version)
        echo "wpclone v${WPCLONE_VERSION}"; exit 0 ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        fatal "Unknown option: $1. Run '$SCRIPT_NAME --help' for usage." ;;
    esac
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Validation
# ─────────────────────────────────────────────────────────────────────────────
validate_args() {
  local errors=0
  local check_fields=("SRC_HOST" "SRC_PATH" "DST_HOST" "DST_PATH")
  [[ $SKIP_URL_REPLACE -eq 0 ]] && check_fields+=("OLD_URL" "NEW_URL")

  for field in "${check_fields[@]}"; do
    if [[ -z "${!field:-}" ]]; then
      error "Missing required option: --${field//_/-,,} ($(echo "--${field}" | tr '[:upper:]' '[:lower:]' | tr '_' '-'))"
      ((errors++))
    fi
  done

  [[ $errors -gt 0 ]] && fatal "Validation failed. Run '$SCRIPT_NAME --help' for usage."

  # Normalize URLs (strip trailing slash)
  OLD_URL="${OLD_URL%/}"
  NEW_URL="${NEW_URL%/}"

  # Validate DB_METHOD
  case "$DB_METHOD" in
    wpcli|mysqldump) ;;
    *) fatal "Invalid --db-method: '$DB_METHOD'. Must be 'wpcli' or 'mysqldump'." ;;
  esac

  debug "Validation passed"
}

# ─────────────────────────────────────────────────────────────────────────────
# SSH Helper
# ─────────────────────────────────────────────────────────────────────────────
_ssh_opts() {
  local host="$1" port="$2" key="${3:-}"
  local opts=(
    -o "StrictHostKeyChecking=no"
    -o "BatchMode=yes"
    -o "ConnectTimeout=15"
    -p "$port"
  )
  [[ -n "$key" ]] && opts+=(-i "$key")
  echo "${opts[@]}"
}

ssh_exec() {
  local target="$1"; shift
  local port="${1}"; shift
  local key="${1:-}"; shift
  local cmd="$*"
  debug "SSH [$target:$port] → $cmd"
  # shellcheck disable=SC2046
  if [[ $DRY_RUN -eq 1 ]]; then
    info "[DRY-RUN] Would run on $target: $cmd"
    return 0
  fi
  # shellcheck disable=SC2046
  ssh $(_ssh_opts "$target" "$port" "$key") "$target" "$cmd"
}

ssh_src() { ssh_exec "$SRC_HOST" "$SRC_PORT" "$SRC_KEY" "$@"; }
ssh_dst() { ssh_exec "$DST_HOST" "$DST_PORT" "$DST_KEY" "$@"; }

# ─────────────────────────────────────────────────────────────────────────────
# Dependency Checks
# ─────────────────────────────────────────────────────────────────────────────
check_local_deps() {
  step "Checking local dependencies"
  local missing=0
  for cmd in ssh rsync; do
    if command -v "$cmd" &>/dev/null; then
      success "$cmd found"
    else
      error "Required command not found locally: $cmd"
      ((missing++))
    fi
  done
  [[ $missing -gt 0 ]] && fatal "Install missing dependencies and retry."
}

check_remote_deps() {
  local target="$1" port="$2" key="$3" label="$4"
  step "Checking remote dependencies on $label ($target)"

  # Check for WP-CLI if needed
  if [[ $SKIP_DB -eq 0 && "$DB_METHOD" == "wpcli" ]]; then
    if ssh_exec "$target" "$port" "$key" "command -v wp" &>/dev/null; then
      success "wp-cli found on $label"
    else
      warn "wp-cli not found on $label — falling back to mysqldump"
      DB_METHOD="mysqldump"
    fi
  fi

  # Check mysqldump if needed
  if [[ $SKIP_DB -eq 0 && "$DB_METHOD" == "mysqldump" ]]; then
    if ssh_exec "$target" "$port" "$key" "command -v mysqldump" &>/dev/null; then
      success "mysqldump found on $label"
    else
      fatal "Neither wp-cli nor mysqldump found on $label. Cannot export database."
    fi
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Rsync File Transfer
# ─────────────────────────────────────────────────────────────────────────────
transfer_files() {
  step "Transferring WordPress files via rsync"

  # Build rsync exclude args
  local exclude_args=()
  # Default excludes — common non-essential paths
  local default_excludes=(
    ".git"
    ".gitignore"
    "wp-content/cache"
    "wp-content/upgrade"
    "*.log"
    ".DS_Store"
    "Thumbs.db"
  )
  for e in "${default_excludes[@]}"; do
    exclude_args+=("--exclude=${e}")
  done
  for e in "${EXCLUDES[@]}"; do
    exclude_args+=("--exclude=${e}")
  done

  # Build rsync SSH options
  local rsync_ssh_opts=(
    "ssh -p ${SRC_PORT} -o StrictHostKeyChecking=no -o ConnectTimeout=15"
  )
  [[ -n "$SRC_KEY" ]] && rsync_ssh_opts=("ssh -p ${SRC_PORT} -i ${SRC_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=15")

  local rsync_flags=(-az --partial --progress)
  [[ $VERBOSE -eq 1 ]] && rsync_flags+=(-v)
  [[ $DRY_RUN -eq 1 ]] && rsync_flags+=(--dry-run)

  # Rsync destination SSH opts
  local dst_transport=()
  local dst_ssh="ssh -p ${DST_PORT} -o StrictHostKeyChecking=no -o ConnectTimeout=15"
  [[ -n "$DST_KEY" ]] && dst_ssh="ssh -p ${DST_PORT} -i ${DST_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=15"

  # Strategy: src → local tmp → dst  OR  if src and dst are on different hosts,
  # we rsync src to local, then local to dst. Most secure approach without
  # requiring direct src↔dst connectivity.
  local local_tmp="${TMP_DIR}/wpfiles"
  mkdir -p "$local_tmp"

  info "Phase 1/2: Pulling files from source → local staging area"
  rsync "${rsync_flags[@]}" \
    -e "${rsync_ssh_opts[*]}" \
    "${exclude_args[@]}" \
    "${SRC_HOST}:${SRC_PATH}/" \
    "${local_tmp}/"

  info "Phase 2/2: Pushing files from local staging → destination"
  rsync "${rsync_flags[@]}" \
    -e "$dst_ssh" \
    "${exclude_args[@]}" \
    "${local_tmp}/" \
    "${DST_HOST}:${DST_PATH}/"

  success "File transfer complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Database Export (Source)
# ─────────────────────────────────────────────────────────────────────────────
export_database() {
  step "Exporting database from source server"
  local remote_dump="/tmp/wpclone_db_$$.sql"
  local local_dump="${TMP_DIR}/dump.sql"

  if [[ "$DB_METHOD" == "wpcli" ]]; then
    info "Using WP-CLI to export database"
    ssh_src "wp --path='${SRC_PATH}' db export '${remote_dump}' --allow-root --quiet" \
      || fatal "WP-CLI db export failed on source"
  else
    info "Using mysqldump to export database"
    # Read wp-config.php to get DB credentials
    local db_name db_user db_pass db_host
    db_name=$(ssh_src "grep \"define.*DB_NAME\" '${SRC_PATH}/wp-config.php' | grep -oP \"'[^']+'\s*,\s*'\\K[^']+\"" 2>/dev/null || true)
    # Fallback: use wp-cli config get
    if [[ -z "$db_name" ]]; then
      db_name=$(ssh_src "wp --path='${SRC_PATH}' config get DB_NAME --allow-root" 2>/dev/null || true)
      db_user=$(ssh_src "wp --path='${SRC_PATH}' config get DB_USER --allow-root" 2>/dev/null || true)
      db_pass=$(ssh_src "wp --path='${SRC_PATH}' config get DB_PASSWORD --allow-root" 2>/dev/null || true)
      db_host=$(ssh_src "wp --path='${SRC_PATH}' config get DB_HOST --allow-root" 2>/dev/null || "localhost")
    else
      db_user=$(ssh_src "grep \"define.*DB_USER\" '${SRC_PATH}/wp-config.php' | grep -oP \"'[^']+'\s*,\s*'\\K[^']+\"" 2>/dev/null || true)
      db_pass=$(ssh_src "grep \"define.*DB_PASSWORD\" '${SRC_PATH}/wp-config.php' | grep -oP \"'[^']+'\s*,\s*'\\K[^']+\"" 2>/dev/null || true)
      db_host=$(ssh_src "grep \"define.*DB_HOST\" '${SRC_PATH}/wp-config.php' | grep -oP \"'[^']+'\s*,\s*'\\K[^']+\"" 2>/dev/null || echo "localhost")
    fi

    [[ -z "$db_name" ]] && fatal "Could not determine DB credentials from source wp-config.php"

    ssh_src "mysqldump -h'${db_host}' -u'${db_user}' -p'${db_pass}' '${db_name}' > '${remote_dump}'" \
      || fatal "mysqldump export failed on source"
  fi

  # Download the dump to local temp
  info "Downloading database dump to local staging"
  if [[ $DRY_RUN -eq 0 ]]; then
    local scp_opts=(-P "$SRC_PORT" -o "StrictHostKeyChecking=no" -o "BatchMode=yes")
    [[ -n "$SRC_KEY" ]] && scp_opts+=(-i "$SRC_KEY")
    scp "${scp_opts[@]}" "${SRC_HOST}:${remote_dump}" "${local_dump}" \
      || fatal "Failed to download database dump from source"
    # Cleanup remote temp dump
    ssh_src "rm -f '${remote_dump}'"
  else
    info "[DRY-RUN] Would download ${SRC_HOST}:${remote_dump} → ${local_dump}"
  fi

  success "Database export complete ($(du -sh "${local_dump}" 2>/dev/null | cut -f1 || echo 'N/A'))"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Database Import (Destination)
# ─────────────────────────────────────────────────────────────────────────────
import_database() {
  step "Importing database to destination server"
  local local_dump="${TMP_DIR}/dump.sql"
  local remote_dump="/tmp/wpclone_db_$$.sql"

  # Upload the dump to destination
  info "Uploading database dump to destination"
  if [[ $DRY_RUN -eq 0 ]]; then
    local scp_opts=(-P "$DST_PORT" -o "StrictHostKeyChecking=no" -o "BatchMode=yes")
    [[ -n "$DST_KEY" ]] && scp_opts+=(-i "$DST_KEY")
    scp "${scp_opts[@]}" "${local_dump}" "${DST_HOST}:${remote_dump}" \
      || fatal "Failed to upload database dump to destination"
  else
    info "[DRY-RUN] Would upload ${local_dump} → ${DST_HOST}:${remote_dump}"
  fi

  if [[ "$DB_METHOD" == "wpcli" ]]; then
    info "Using WP-CLI to import database"
    ssh_dst "wp --path='${DST_PATH}' db import '${remote_dump}' --allow-root" \
      || fatal "WP-CLI db import failed on destination"
  else
    info "Using mysql to import database"
    # Get dst DB credentials
    local db_name db_user db_pass db_host
    db_name=$(ssh_dst "wp --path='${DST_PATH}' config get DB_NAME --allow-root" 2>/dev/null \
      || ssh_dst "grep \"define.*DB_NAME\" '${DST_PATH}/wp-config.php' | grep -oP \"'[^']+'\s*,\s*'\\K[^']+\"" 2>/dev/null || true)
    db_user=$(ssh_dst "wp --path='${DST_PATH}' config get DB_USER --allow-root" 2>/dev/null \
      || ssh_dst "grep \"define.*DB_USER\" '${DST_PATH}/wp-config.php' | grep -oP \"'[^']+'\s*,\s*'\\K[^']+\"" 2>/dev/null || true)
    db_pass=$(ssh_dst "wp --path='${DST_PATH}' config get DB_PASSWORD --allow-root" 2>/dev/null \
      || ssh_dst "grep \"define.*DB_PASSWORD\" '${DST_PATH}/wp-config.php' | grep -oP \"'[^']+'\s*,\s*'\\K[^']+\"" 2>/dev/null || true)
    db_host=$(ssh_dst "wp --path='${DST_PATH}' config get DB_HOST --allow-root" 2>/dev/null || echo "localhost")

    [[ -z "$db_name" ]] && fatal "Could not determine DB credentials from destination wp-config.php"

    ssh_dst "mysql -h'${db_host}' -u'${db_user}' -p'${db_pass}' '${db_name}' < '${remote_dump}'" \
      || fatal "mysql import failed on destination"
  fi

  # Cleanup remote temp dump
  ssh_dst "rm -f '${remote_dump}'"

  success "Database import complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: URL Search & Replace
# ─────────────────────────────────────────────────────────────────────────────
replace_urls() {
  step "Running URL search-and-replace: ${OLD_URL} → ${NEW_URL}"

  if [[ "$OLD_URL" == "$NEW_URL" ]]; then
    warn "OLD_URL and NEW_URL are identical — skipping search-replace"
    return 0
  fi

  if [[ "$DB_METHOD" == "wpcli" ]]; then
    info "Using WP-CLI search-replace (handles serialized PHP safely)"
    ssh_dst "wp --path='${DST_PATH}' search-replace \
      '${OLD_URL}' '${NEW_URL}' \
      --all-tables \
      --allow-root \
      --report-changed-only \
      $([ $DRY_RUN -eq 1 ] && echo '--dry-run')" \
      || fatal "WP-CLI search-replace failed"
  else
    warn "WP-CLI not available — using sed-based URL replace (does NOT handle serialized data)"
    warn "Serialized data may become corrupt. Install WP-CLI on the destination for reliable replacement."

    ssh_dst "sed -i 's|${OLD_URL}|${NEW_URL}|g' /tmp/wpclone_urlfix.tmp 2>/dev/null; \
      wp --path='${DST_PATH}' db export /tmp/wpclone_urlfix.sql --allow-root 2>/dev/null || true; \
      if [ -f /tmp/wpclone_urlfix.sql ]; then \
        sed -i 's|${OLD_URL}|${NEW_URL}|g' /tmp/wpclone_urlfix.sql; \
        wp --path='${DST_PATH}' db import /tmp/wpclone_urlfix.sql --allow-root; \
        rm -f /tmp/wpclone_urlfix.sql; \
      fi" \
      || fatal "sed-based search-replace failed"
  fi

  # Also update siteurl and home options directly just in case
  if ! ssh_dst "wp --path='${DST_PATH}' option get siteurl --allow-root" &>/dev/null; then
    warn "Could not verify siteurl option post-replace (wp-cli may be unavailable)"
  else
    local siteurl; siteurl=$(ssh_dst "wp --path='${DST_PATH}' option get siteurl --allow-root")
    if [[ "$siteurl" == "$NEW_URL" || "$siteurl" == "${NEW_URL}/" ]]; then
      success "siteurl confirmed: $siteurl"
    else
      warn "siteurl is '$siteurl' — expected '$NEW_URL'. You may need to update manually."
    fi
  fi

  success "URL replacement complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 5: Post-migration Checks
# ─────────────────────────────────────────────────────────────────────────────
post_migration_checks() {
  step "Running post-migration checks"

  # Flush cache / rewrite rules if WP-CLI available
  if ssh_dst "command -v wp" &>/dev/null; then
    info "Flushing WordPress cache and rewrite rules"
    ssh_dst "wp --path='${DST_PATH}' cache flush --allow-root 2>/dev/null || true"
    ssh_dst "wp --path='${DST_PATH}' rewrite flush --allow-root 2>/dev/null || true"
    success "Cache and rewrite rules flushed"

    # Print site core info
    info "Destination site info:"
    ssh_dst "wp --path='${DST_PATH}' core version --allow-root 2>/dev/null" \
      | while read -r line; do info "  WP version: $line"; done

    ssh_dst "wp --path='${DST_PATH}' option get siteurl --allow-root 2>/dev/null" \
      | while read -r line; do info "  Site URL:   $line"; done
  else
    warn "WP-CLI not found on destination — skipping cache flush"
  fi

  # Fix file permissions
  info "Setting recommended file permissions on destination"
  ssh_dst "find '${DST_PATH}' -type d -exec chmod 755 {} \; 2>/dev/null || true"
  ssh_dst "find '${DST_PATH}' -type f -exec chmod 644 {} \; 2>/dev/null || true"
  ssh_dst "chmod 600 '${DST_PATH}/wp-config.php' 2>/dev/null || true"
  success "File permissions updated"
}

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────────────────────
cleanup() {
  if [[ -d "${TMP_DIR}" ]]; then
    debug "Cleaning up temp directory: ${TMP_DIR}"
    rm -rf "${TMP_DIR}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Print Migration Summary Banner
# ─────────────────────────────────────────────────────────────────────────────
print_summary() {
  printf '\n'
  printf '%s%s╔══════════════════════════════════════════════════════════╗%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s║           wpclone Migration Summary                     ║%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s╚══════════════════════════════════════════════════════════╝%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '\n'
  printf '  %s%-20s%s %s\n' "$BOLD" "Source Host:"      "$RESET" "$SRC_HOST"
  printf '  %s%-20s%s %s\n' "$BOLD" "Source Path:"      "$RESET" "$SRC_PATH"
  printf '  %s%-20s%s %s\n' "$BOLD" "Destination Host:" "$RESET" "$DST_HOST"
  printf '  %s%-20s%s %s\n' "$BOLD" "Destination Path:" "$RESET" "$DST_PATH"
  printf '  %s%-20s%s %s\n' "$BOLD" "Old URL:"          "$RESET" "${OLD_URL:-N/A}"
  printf '  %s%-20s%s %s\n' "$BOLD" "New URL:"          "$RESET" "${NEW_URL:-N/A}"
  printf '  %s%-20s%s %s\n' "$BOLD" "DB Method:"        "$RESET" "$DB_METHOD"
  printf '  %s%-20s%s %s\n' "$BOLD" "Skip Files:"       "$RESET" "$([[ $SKIP_FILES -eq 1 ]] && echo yes || echo no)"
  printf '  %s%-20s%s %s\n' "$BOLD" "Skip DB:"          "$RESET" "$([[ $SKIP_DB -eq 1 ]] && echo yes || echo no)"
  printf '  %s%-20s%s %s\n' "$BOLD" "Skip URL Replace:" "$RESET" "$([[ $SKIP_URL_REPLACE -eq 1 ]] && echo yes || echo no)"
  printf '  %s%-20s%s %s\n' "$BOLD" "Dry Run:"          "$RESET" "$([[ $DRY_RUN -eq 1 ]] && echo YES || echo no)"
  printf '\n'
  [[ $DRY_RUN -eq 1 ]] && printf '  %s%sDRY RUN MODE — No changes will be made.%s\n\n' "$YELLOW" "$BOLD" "$RESET"
}

confirm_proceed() {
  if [[ $DRY_RUN -eq 0 && -t 0 ]]; then
    printf '%s%s⚠  This will overwrite files and/or the database on the destination server.%s\n' "$YELLOW" "$BOLD" "$RESET"
    read -r -p "   Proceed? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted by user."; cleanup; exit 0; }
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
main() {
  # Init log
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "=== wpclone v${WPCLONE_VERSION} | $(date) ===" >> "$LOG_FILE"

  parse_args "$@"
  validate_args
  print_summary

  # Trap for cleanup on exit/error
  trap cleanup EXIT
  trap 'fatal "Interrupted by user (SIGINT)"' INT
  trap 'fatal "Process terminated (SIGTERM)"' TERM

  confirm_proceed

  # Create temp workspace
  mkdir -p "${TMP_DIR}"

  check_local_deps
  check_remote_deps "$SRC_HOST" "$SRC_PORT" "$SRC_KEY" "source"
  check_remote_deps "$DST_HOST" "$DST_PORT" "$DST_KEY" "destination"

  # ── File Transfer ──────────────────────────────────────────────────────────
  if [[ $SKIP_FILES -eq 0 ]]; then
    transfer_files
  else
    warn "Skipping file transfer (--skip-files)"
  fi

  # ── Database Migration ────────────────────────────────────────────────────
  if [[ $SKIP_DB -eq 0 ]]; then
    export_database
    import_database
  else
    warn "Skipping database migration (--skip-db)"
  fi

  # ── URL Replacement ───────────────────────────────────────────────────────
  if [[ $SKIP_URL_REPLACE -eq 0 && $SKIP_DB -eq 0 ]]; then
    replace_urls
  else
    warn "Skipping URL replacement"
  fi

  # ── Post-migration ────────────────────────────────────────────────────────
  post_migration_checks

  # Done!
  printf '\n'
  printf '%s%s╔══════════════════════════════════════════════╗%s\n' "$GREEN" "$BOLD" "$RESET"
  printf '%s%s║   ✓ Migration completed successfully!        ║%s\n' "$GREEN" "$BOLD" "$RESET"
  printf '%s%s╚══════════════════════════════════════════════╝%s\n' "$GREEN" "$BOLD" "$RESET"
  printf '\n'
  success "Log saved to: ${LOG_FILE}"
  printf '\n'
}

main "$@"
