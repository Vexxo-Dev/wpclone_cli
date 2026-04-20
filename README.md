# wpclone — WordPress Site Migration Tool

> **One-command WordPress migration** between servers using SSH, rsync, and WP-CLI.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Status](https://img.shields.io/badge/status-early%20development-orange.svg)]()
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![GitHub issues](https://img.shields.io/github/issues/youruser/wpclone)](https://github.com/youruser/wpclone/issues)
[![GitHub stars](https://img.shields.io/github/stars/youruser/wpclone?style=flat)](https://github.com/youruser/wpclone/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/youruser/wpclone?style=flat)](https://github.com/youruser/wpclone/network)

---

## ✨ Features

| Feature | Details |
|---|---|
| **File Transfer** | rsync over SSH — incremental, resume-safe, fast |
| **Database Export** | WP-CLI (`wp db export`) or `mysqldump` fallback |
| **Database Import** | WP-CLI (`wp db import`) or `mysql` fallback |
| **URL Replacement** | `wp search-replace` — handles serialized PHP safely |
| **Config File** | Reusable `.conf` files for repeatable migrations |
| **Dry Run** | Preview every step without touching anything |
| **Post-migration** | Cache flush, rewrite rules, permission hardening |
| **Logging** | Full log of every operation to `wpclone.log` |

---

## 📊 Community Stats

> Track how many migrations have been run and sites moved using wpclone.

| Metric | Badge |
|---|---|
| Total migrations run | [![GitHub Discussions](https://img.shields.io/github/discussions/youruser/wpclone?label=migrations%20shared)](https://github.com/youruser/wpclone/discussions) |
| Open issues / bug reports | [![GitHub issues](https://img.shields.io/github/issues/youruser/wpclone)](https://github.com/youruser/wpclone/issues) |
| Closed (resolved) issues | [![GitHub closed issues](https://img.shields.io/github/issues-closed/youruser/wpclone?color=green)](https://github.com/youruser/wpclone/issues?q=is%3Aissue+is%3Aclosed) |
| Stars (people using it) | [![GitHub stars](https://img.shields.io/github/stars/youruser/wpclone)](https://github.com/youruser/wpclone/stargazers) |

> 💬 **Ran a successful migration?** [Tell us about it in Discussions!](https://github.com/youruser/wpclone/discussions/new?category=show-and-tell)
> We love hearing which sites you've migrated. It helps others trust the tool.

---

## 📦 Requirements

### On your local machine (where you run `wpclone`):
- `bash` ≥ 4.0
- `ssh`
- `rsync`
- `scp`

### On the **source** server:
- `ssh` access
- `wp-cli` *(recommended)* or `mysqldump`

### On the **destination** server:
- `ssh` access
- `wp-cli` *(recommended)* or `mysql`
- A working WordPress installation with `wp-config.php` already in place

> **Tip:** No extra packages needed beyond what's standard on any Linux server.

---

## 🚀 Quick Start

### ⚡ One-liner (no cloning required)

Run wpclone directly from GitHub — no installation, no `git clone`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/youruser/wpclone/main/wpclone.sh) \
  --src-host deploy@old-server.com \
  --src-path /var/www/html \
  --dst-host deploy@new-server.com \
  --dst-path /var/www/html \
  --old-url https://old-site.com \
  --new-url https://new-site.com
```

### Install locally (recommended for repeated use)

```bash
# Download and make executable
curl -fsSL https://raw.githubusercontent.com/youruser/wpclone/main/wpclone.sh -o wpclone
chmod +x wpclone

# Optional: install system-wide
sudo mv wpclone /usr/local/bin/wpclone

# Verify
wpclone --version
```

### Run a full migration

```bash
./wpclone \
  --src-host deploy@old-server.com \
  --src-path /var/www/html \
  --dst-host deploy@new-server.com \
  --dst-path /var/www/html \
  --old-url https://old-site.com \
  --new-url https://new-site.com
```

---

## ⚙️ Usage

```
wpclone [OPTIONS]
wpclone --config <file>
```

### Required Options

| Option | Description |
|---|---|
| `--src-host <user@host>` | SSH string for the source server |
| `--src-path <path>` | Absolute WP root path on the source |
| `--dst-host <user@host>` | SSH string for the destination server |
| `--dst-path <path>` | Absolute WP root path on the destination |
| `--old-url <url>` | Old site URL (as stored in the WP database) |
| `--new-url <url>` | New site URL |

### Optional Flags

| Option | Description |
|---|---|
| `--config <file>` | Load options from a config file |
| `--src-port <port>` | SSH port on source (default: `22`) |
| `--dst-port <port>` | SSH port on destination (default: `22`) |
| `--src-key <path>` | SSH private key for source |
| `--dst-key <path>` | SSH private key for destination |
| `--db-method <m>` | `wpcli` (default) or `mysqldump` |
| `--exclude <pattern>` | Rsync exclude pattern (repeatable) |
| `--skip-files` | Skip rsync transfer (DB only) |
| `--skip-db` | Skip database migration (files only) |
| `--skip-url-replace` | Skip search-and-replace after import |
| `--dry-run` | Simulate without making changes |
| `--verbose` | Verbose rsync output |
| `--no-color` | Disable colored output |
| `--version` | Print version and exit |
| `-h, --help` | Show help |

### Environment Variables

| Variable | Description |
|---|---|
| `WPCLONE_DEBUG=1` | Enable debug output |
| `WPCLONE_LOG=<path>` | Override log file location |

---

## 📄 Config File

Copy `migration.conf.example` to `migration.conf`, fill in your values, and run:

```bash
./wpclone --config migration.conf
```

Config file format (key=value, comments with `#`):

```ini
SRC_HOST=deploy@old-server.com
SRC_PATH=/var/www/html
DST_HOST=deploy@new-server.com
DST_PATH=/var/www/html
OLD_URL=https://old-site.com
NEW_URL=https://new-site.com
DB_METHOD=wpcli
VERBOSE=0
DRY_RUN=0
```

---

## 🎯 Use Cases

### Migrate live → new host
```bash
./wpclone --config production.conf
```

### Clone live → staging
```bash
./wpclone --config production.conf --new-url https://staging.example.com
```

### Sync files only (e.g. after a code deploy)
```bash
./wpclone --config production.conf --skip-db
```

### Restore database only
```bash
./wpclone --config production.conf --skip-files
```

### Preview everything before running
```bash
./wpclone --config production.conf --dry-run
```

### Exclude large upload folders
```bash
./wpclone --config production.conf \
  --exclude wp-content/uploads/videos \
  --exclude wp-content/uploads/2020
```

---

## 🔄 Migration Flow

```
┌─────────────────────────────────────────────────────────┐
│                       wpclone                           │
│                                                         │
│  1. Validate args & check deps (local + remote)         │
│                                                         │
│  2. rsync: source → local staging → destination         │
│                                                         │
│  3. Export DB: source (wp db export / mysqldump)        │
│     ↓ scp to local                                      │
│  4. Import DB: scp to destination → wp db import / mysql│
│                                                         │
│  5. wp search-replace: old URL → new URL                │
│     (handles serialized PHP safely)                     │
│                                                         │
│  6. Post-migration:                                     │
│     - wp cache flush                                    │
│     - wp rewrite flush                                  │
│     - chmod 755/644, wp-config.php 600                  │
└─────────────────────────────────────────────────────────┘
```

---

## 🛡️ Security Notes

- SSH `BatchMode=yes` is used — no interactive password prompts. Use SSH keys.
- `wp-config.php` is set to `chmod 600` on the destination after migration.
- Database credentials are never written to local disk (only the dump file is, in `/tmp`).
- The local staging area is always cleaned up on exit (even on error).

---

## 🐛 Bug Reports & Support

Ran into a problem? Please [open a GitHub Issue](https://github.com/youruser/wpclone/issues/new/choose) and include:

| Field | What to include |
|---|---|
| **OS / environment** | Local OS, bash version (`bash --version`) |
| **SSH setup** | Key auth or password? Direct access or jump host? |
| **WP-CLI available?** | Run `wp --info` on both servers |
| **Error message** | Full output from the terminal |
| **Log file** | Contents of `wpclone.log` (redact passwords/IPs if needed) |
| **Command used** | The exact `wpclone` command (redact credentials) |

> [!TIP]
> Run with `--dry-run` and `WPCLONE_DEBUG=1` first to capture full output without making any changes:
> ```bash
> WPCLONE_DEBUG=1 ./wpclone --config migration.conf --dry-run 2>&1 | tee debug.log
> ```
> Then attach `debug.log` and `wpclone.log` to your issue.

**Quick links:**
- 🐛 [Report a bug](https://github.com/youruser/wpclone/issues/new?template=bug_report.md)
- 💡 [Request a feature](https://github.com/youruser/wpclone/issues/new?template=feature_request.md)
- 💬 [Start a discussion](https://github.com/youruser/wpclone/discussions)

---

## 🤝 Contributing

Contributions are very welcome! This project is in early development.

### Ways to contribute:
- Add support for **direct SSH tunnelling** (src ↔ dst without local staging)
- Add **progress bars** using `pv` for database transfer
- Add **Slack/email notifications** on completion
- Add a **rollback** mechanism (snapshot before migration)
- Write **tests** (BATS framework)
- Improve **Windows/WSL** compatibility

Please open an issue before submitting large PRs. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📋 Roadmap

- [ ] Direct server-to-server rsync (no local staging required)
- [ ] `--backup` flag — snapshot destination before overwriting
- [ ] Interactive TUI mode
- [ ] Slack/webhook notifications
- [ ] BATS test suite
- [ ] `brew install` / `apt install` packaging
- [ ] Docker image for environments without rsync/ssh

---

## 📜 License

MIT © 2026 — See [LICENSE](LICENSE) for details.
