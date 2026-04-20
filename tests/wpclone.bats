#!/usr/bin/env bash
# =============================================================================
# wpclone — Test Suite
# Uses BATS (Bash Automated Testing System)
# Install: https://github.com/bats-core/bats-core
# Run: bats tests/wpclone.bats
# =============================================================================

# Load BATS helpers if available
setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  WPCLONE="${SCRIPT_DIR}/wpclone.sh"
  chmod +x "$WPCLONE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────

@test "prints version" {
  run "$WPCLONE" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^wpclone\ v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "prints help" {
  run "$WPCLONE" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "USAGE" ]]
}

@test "no arguments shows help" {
  run "$WPCLONE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "USAGE" ]]
}

@test "fails on unknown option" {
  run "$WPCLONE" --foo-bar
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Unknown option" ]]
}

@test "fails when required args missing" {
  run "$WPCLONE" --src-host user@host
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Missing required option" ]]
}

@test "fails with invalid db-method" {
  run "$WPCLONE" \
    --src-host user@src --src-path /wp \
    --dst-host user@dst --dst-path /wp \
    --old-url https://old.com --new-url https://new.com \
    --db-method badmethod --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Invalid --db-method" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Config File
# ─────────────────────────────────────────────────────────────────────────────

@test "loads valid config file" {
  local cfg; cfg="$(mktemp /tmp/wpclone_test_XXXX.conf)"
  cat > "$cfg" <<'CONFIG'
SRC_HOST=user@src.example.com
SRC_PATH=/var/www/html
DST_HOST=user@dst.example.com
DST_PATH=/var/www/html
OLD_URL=https://old.example.com
NEW_URL=https://new.example.com
DRY_RUN=1
CONFIG
  run "$WPCLONE" --config "$cfg"
  # Dry run should not fail on missing SSH (just prints summary and exits)
  rm -f "$cfg"
  # We just check it didn't error on config parsing
  [[ "$output" =~ "user@src.example.com" ]]
}

@test "fails on missing config file" {
  run "$WPCLONE" --config /nonexistent/path/config.conf
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Config file not found" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# URL Normalization
# ─────────────────────────────────────────────────────────────────────────────

@test "strips trailing slash from urls in dry-run summary" {
  run "$WPCLONE" \
    --src-host user@src --src-path /wp \
    --dst-host user@dst --dst-path /wp \
    --old-url "https://old.com/" \
    --new-url "https://new.com/" \
    --dry-run
  # Should not crash; trailing slash removed
  [[ "$output" =~ "https://old.com" ]]
  [[ ! "$output" =~ "https://old.com/" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Skip Flags
# ─────────────────────────────────────────────────────────────────────────────

@test "dry-run with --skip-files shows warning" {
  run "$WPCLONE" \
    --src-host user@src --src-path /wp \
    --dst-host user@dst --dst-path /wp \
    --old-url https://old.com --new-url https://new.com \
    --skip-files --dry-run
  [[ "$output" =~ "skip-files" || "$output" =~ "Skip Files" ]]
}

@test "dry-run with --skip-db shows warning" {
  run "$WPCLONE" \
    --src-host user@src --src-path /wp \
    --dst-host user@dst --dst-path /wp \
    --old-url https://old.com --new-url https://new.com \
    --skip-db --dry-run
  [[ "$output" =~ "Skip DB" ]]
}
