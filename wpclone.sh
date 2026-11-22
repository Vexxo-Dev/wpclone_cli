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
  # NOTE: `if` instead of `[[ ... ]] && ...` — under `set -e` a function whose
  # last command is a false `&&` test returns 1 and silently kills the script.
  if [[ "${WPCLONE_DEBUG:-0}" == "1" ]]; then
    printf '%s[DEBUG] %s%s\n' "$DIM" "$*" "$RESET"
  fi
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
  --include-wp-config         Also copy wp-config.php (excluded by default so the
                              destination keeps its own DB credentials)
  --no-json-urls              Skip the extra search-replace of JSON-escaped URLs
                              (https:\/\/old → https:\/\/new, used by Elementor)
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
INCLUDE_WP_CONFIG=0
REPLACE_JSON_URLS=1
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
      INCLUDE_WP_CONFIG) INCLUDE_WP_CONFIG="$value" ;;
      REPLACE_JSON_URLS) REPLACE_JSON_URLS="$value" ;;
      EXCLUDE)        EXCLUDES+=("$value")    ;;
      *)              warn "Unknown config key ignored: $key" ;;
    esac
  done < "$cfg"
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────
parse_args() {
  if [[ $# -eq 0 ]]; then usage; exit 0; fi

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
      --include-wp-config) INCLUDE_WP_CONFIG=1; shift ;;
      --no-json-urls) REPLACE_JSON_URLS=0; shift ;;
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
  if [[ $SKIP_URL_REPLACE -eq 0 ]]; then
    check_fields+=("OLD_URL" "NEW_URL")
  fi

  for field in "${check_fields[@]}"; do
    if [[ -z "${!field:-}" ]]; then
      error "Missing required option: $(echo "--${field}" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
      # NOTE: not ((errors++)) — that returns 1 when errors is 0 and trips set -e
      errors=$((errors + 1))
    fi
  done

  if [[ $errors -gt 0 ]]; then
    fatal "Validation failed. Run '$SCRIPT_NAME --help' for usage."
  fi

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
ssh_exec() {
  local target="$1"; shift
  local port="${1}"; shift
  local key="${1:-}"; shift
  local cmd="$*"
  debug "SSH [$target:$port] → $cmd"
  if [[ $DRY_RUN -eq 1 ]]; then
    # stderr, so callers that capture stdout with $(...) don't get this text
    info "[DRY-RUN] Would run on $target: $cmd" >&2
    return 0
  fi
  # Build options as an array. The script sets IFS=$'\n\t', so the old
  # `ssh $(_ssh_opts ...)` was not split on spaces: all options reached ssh as
  # ONE argument ("keyword stricthostkeychecking extra arguments").
  local sshopts=(-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=15 -p "$port")
  if [[ -n "$key" ]]; then
    sshopts+=(-i "$key")
  fi
  ssh "${sshopts[@]}" "$target" "$cmd"
}

ssh_src() { ssh_exec "$SRC_HOST" "$SRC_PORT" "$SRC_KEY" "$@"; }
ssh_dst() { ssh_exec "$DST_HOST" "$DST_PORT" "$DST_KEY" "$@"; }

# Single-quote a string for safe use inside a remote shell command.
_sq() { local q="'" r="'\\''" s; s="${1//$q/$r}"; printf "'%s'" "$s"; }

# ─────────────────────────────────────────────────────────────────────────────
# Database credential helpers
# ─────────────────────────────────────────────────────────────────────────────
# Read a wp-config.php define() on side "src" or "dst".
# Tries `wp config get` first, then falls back to grepping wp-config.php.
_wp_config_get() {
  local side="$1" key="$2" path val=""
  if [[ "$side" == "src" ]]; then path="$SRC_PATH"; else path="$DST_PATH"; fi
  val=$("ssh_${side}" "wp --path=$(_sq "$path") config get ${key} --allow-root 2>/dev/null" 2>/dev/null) || val=""
  if [[ -z "$val" ]]; then
    val=$("ssh_${side}" "grep \"define.*${key}\" $(_sq "${path}/wp-config.php") | grep -oP \"'[^']+'\s*,\s*'\\K[^']*\" | head -n1" 2>/dev/null) || val=""
  fi
  printf '%s' "$val"
}

# Populate DBC_NAME / DBC_USER / DBC_PASS / DBC_HOST for side "src" or "dst".
DBC_NAME="" DBC_USER="" DBC_PASS="" DBC_HOST=""
_load_db_creds() {
  local side="$1"
  if [[ $DRY_RUN -eq 1 ]]; then
    DBC_NAME="<${side}_db_name>" DBC_USER="<${side}_db_user>" DBC_PASS="" DBC_HOST="localhost"
    return 0
  fi
  DBC_NAME=$(_wp_config_get "$side" DB_NAME)
  DBC_USER=$(_wp_config_get "$side" DB_USER)
  DBC_PASS=$(_wp_config_get "$side" DB_PASSWORD)
  DBC_HOST=$(_wp_config_get "$side" DB_HOST)
  DBC_HOST="${DBC_HOST:-localhost}"
  if [[ -z "$DBC_NAME" || -z "$DBC_USER" ]]; then
    fatal "Could not determine DB credentials from ${side} wp-config.php"
  fi
}

# mysql/mysqldump connection args (quoted for the remote shell) from DBC_*.
# Handles DB_HOST values like "localhost:3306" and "localhost:/path/to.sock".
# The password is NOT included — it is sent over stdin into MYSQL_PWD so it
# never appears in argv, `ps` output, or wpclone.log.
_mysql_conn_args() {
  local host="$DBC_HOST" rest="" args
  if [[ "$host" == *:* ]]; then
    rest="${host#*:}"; host="${host%%:*}"
  fi
  args="-h $(_sq "$host") -u $(_sq "$DBC_USER")"
  if [[ "$rest" =~ ^[0-9]+$ ]]; then
    args+=" -P ${rest}"
  elif [[ -n "$rest" ]]; then
    args+=" --socket=$(_sq "$rest")"
  fi
  printf '%s' "$args"
}

# Remote prefix that reads the DB password from stdin into MYSQL_PWD.
readonly _PWD_FROM_STDIN='IFS= read -r MYSQL_PWD; export MYSQL_PWD;'

_mysqldump_export() {
  local remote_dump="$1"
  _load_db_creds src
  info "Running mysqldump on source (database: ${DBC_NAME})"
  ssh_src "${_PWD_FROM_STDIN} mysqldump $(_mysql_conn_args) --single-transaction --no-tablespaces --default-character-set=utf8mb4 $(_sq "$DBC_NAME") > $(_sq "$remote_dump") && test -s $(_sq "$remote_dump")" \
    <<< "$DBC_PASS"
}

_mysql_import() {
  local remote_dump="$1"
  _load_db_creds dst
  info "Running mysql import on destination (database: ${DBC_NAME})"
  ssh_dst "${_PWD_FROM_STDIN} mysql $(_mysql_conn_args) --default-character-set=utf8mb4 $(_sq "$DBC_NAME") < $(_sq "$remote_dump")" \
    <<< "$DBC_PASS"
}

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
      missing=$((missing + 1))
    fi
  done
  # `if`, not `[[ ]] && fatal`: as the last line that returned 1 and set -e
  # exited the whole script silently right after "ssh found / rsync found".
  if [[ $missing -gt 0 ]]; then
    fatal "Install missing dependencies and retry."
  fi
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
    "wp-content/upgrade-temp-backup"
    "wp-content/litespeed"
    "wp-content/backups-dup-lite"
    "*.log"
    ".DS_Store"
    "Thumbs.db"
  )
  # Never overwrite the destination's wp-config.php by default — it holds the
  # destination's own DB credentials. Leading "/" anchors it to the WP root.
  if [[ $INCLUDE_WP_CONFIG -ne 1 ]]; then
    default_excludes+=("/wp-config.php")
  fi
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
  if [[ -n "$SRC_KEY" ]]; then
    rsync_ssh_opts=("ssh -p ${SRC_PORT} -i ${SRC_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=15")
  fi

  local rsync_flags=(-az --partial --progress)
  if [[ $VERBOSE -eq 1 ]]; then rsync_flags+=(-v); fi
  if [[ $DRY_RUN -eq 1 ]]; then rsync_flags+=(--dry-run); fi

  # Rsync destination SSH opts
  local dst_ssh="ssh -p ${DST_PORT} -o StrictHostKeyChecking=no -o ConnectTimeout=15"
  if [[ -n "$DST_KEY" ]]; then
    dst_ssh="ssh -p ${DST_PORT} -i ${DST_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=15"
  fi

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
    # On some Hostinger servers `wp db export` exits 255 with no output; also
    # guard against it "succeeding" with an empty file. Fall back to mysqldump
    # using credentials from `wp config get`.
    if ! ssh_src "wp --path=$(_sq "$SRC_PATH") db export $(_sq "$remote_dump") --allow-root --quiet && test -s $(_sq "$remote_dump")"; then
      warn "WP-CLI db export failed on source — falling back to mysqldump"
      _mysqldump_export "$remote_dump" || fatal "mysqldump fallback export failed on source"
    fi
  else
    info "Using mysqldump to export database"
    _mysqldump_export "$remote_dump" || fatal "mysqldump export failed on source"
  fi

  # Download the dump to local temp
  info "Downloading database dump to local staging"
  if [[ $DRY_RUN -eq 0 ]]; then
    local scp_opts=(-P "$SRC_PORT" -o "StrictHostKeyChecking=no" -o "BatchMode=yes")
    if [[ -n "$SRC_KEY" ]]; then scp_opts+=(-i "$SRC_KEY"); fi
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
    if [[ -n "$DST_KEY" ]]; then scp_opts+=(-i "$DST_KEY"); fi
    scp "${scp_opts[@]}" "${local_dump}" "${DST_HOST}:${remote_dump}" \
      || fatal "Failed to upload database dump to destination"
  else
    info "[DRY-RUN] Would upload ${local_dump} → ${DST_HOST}:${remote_dump}"
  fi

  if [[ "$DB_METHOD" == "wpcli" ]]; then
    info "Using WP-CLI to import database"
    if ! ssh_dst "wp --path=$(_sq "$DST_PATH") db import $(_sq "$remote_dump") --allow-root"; then
      warn "WP-CLI db import failed on destination — falling back to mysql"
      _mysql_import "$remote_dump" || fatal "mysql fallback import failed on destination"
    fi
  else
    info "Using mysql to import database"
    _mysql_import "$remote_dump" || fatal "mysql import failed on destination"
  fi

  # Cleanup remote temp dump
  ssh_dst "rm -f $(_sq "$remote_dump")"

  success "Database import complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: URL Search & Replace
# ─────────────────────────────────────────────────────────────────────────────
_wp_search_replace() {
  local from="$1" to="$2" extra=""
  if [[ $DRY_RUN -eq 1 ]]; then extra=" --dry-run"; fi
  ssh_dst "wp --path=$(_sq "$DST_PATH") search-replace $(_sq "$from") $(_sq "$to") --all-tables --allow-root --report-changed-only${extra}"
}

replace_urls() {
  step "Running URL search-and-replace: ${OLD_URL} → ${NEW_URL}"

  if [[ "$OLD_URL" == "$NEW_URL" ]]; then
    warn "OLD_URL and NEW_URL are identical — skipping search-replace"
    return 0
  fi

  # Use wp search-replace whenever wp-cli exists on the destination, regardless
  # of DB_METHOD — sed on a SQL dump corrupts serialized PHP string lengths.
  if ssh_dst "command -v wp" &>/dev/null; then
    info "Using WP-CLI search-replace (handles serialized PHP safely)"
    _wp_search_replace "$OLD_URL" "$NEW_URL" || fatal "WP-CLI search-replace failed"

    # Elementor (and other JSON blobs, e.g. _elementor_data) store URLs with
    # escaped slashes: https:\/\/old-site.com — the plain replace misses them.
    if [[ $REPLACE_JSON_URLS -eq 1 ]]; then
      local slash='/' esc='\/' old_json new_json
      old_json="${OLD_URL//$slash/$esc}" new_json="${NEW_URL//$slash/$esc}"
      info "Replacing JSON-escaped URLs: ${old_json} → ${new_json}"
      _wp_search_replace "$old_json" "$new_json" || fatal "WP-CLI search-replace (JSON-escaped URLs) failed"
    fi
  else
    warn "WP-CLI not available on destination — using sed-based URL replace (does NOT handle serialized data)"
    warn "Serialized data may become corrupt. Install WP-CLI on the destination for reliable replacement."

    _load_db_creds dst
    local tmp="/tmp/wpclone_urlfix_$$.sql" conn old_re new_re
    conn=$(_mysql_conn_args)
    old_re=$(printf '%s' "$OLD_URL" | sed -e 's/[]\/$*.^|[]/\\&/g')
    new_re=$(printf '%s' "$NEW_URL" | sed -e 's/[\/&|]/\\&/g')
    ssh_dst "${_PWD_FROM_STDIN} \
      mysqldump ${conn} --single-transaction --no-tablespaces --default-character-set=utf8mb4 $(_sq "$DBC_NAME") > $(_sq "$tmp") \
      && sed -i $(_sq "s|${old_re}|${new_re}|g") $(_sq "$tmp") \
      && mysql ${conn} --default-character-set=utf8mb4 $(_sq "$DBC_NAME") < $(_sq "$tmp"); \
      rc=\$?; rm -f $(_sq "$tmp"); exit \$rc" <<< "$DBC_PASS" \
      || fatal "sed-based search-replace failed"
  fi

  # Verify siteurl after the replace
  if [[ $DRY_RUN -eq 1 ]]; then
    info "[DRY-RUN] Would verify siteurl == ${NEW_URL}"
  elif ! ssh_dst "wp --path=$(_sq "$DST_PATH") option get siteurl --allow-root" &>/dev/null; then
    warn "Could not verify siteurl option post-replace (wp-cli may be unavailable)"
  else
    local siteurl; siteurl=$(ssh_dst "wp --path=$(_sq "$DST_PATH") option get siteurl --allow-root")
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
  printf '  %s%-20s%s %s\n' "$BOLD" "Copy wp-config.php:" "$RESET" "$([[ $INCLUDE_WP_CONFIG -eq 1 ]] && echo yes || echo no)"
  printf '  %s%-20s%s %s\n' "$BOLD" "JSON URL Replace:" "$RESET" "$([[ $REPLACE_JSON_URLS -eq 1 ]] && echo yes || echo no)"
  printf '  %s%-20s%s %s\n' "$BOLD" "Dry Run:"          "$RESET" "$([[ $DRY_RUN -eq 1 ]] && echo YES || echo no)"
  printf '\n'
  # `if`, not `[[ ]] && printf`: as the last line that made print_summary
  # return 1 on every real run, and set -e stopped the script right here.
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  %s%sDRY RUN MODE — No changes will be made.%s\n\n' "$YELLOW" "$BOLD" "$RESET"
  fi
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
