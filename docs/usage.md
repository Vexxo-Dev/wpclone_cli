---
layout: page
title: Usage
permalink: /usage/
---

# Usage

```text
wpclone [OPTIONS]
wpclone --config <file>
```

## Required options

- --src-host <user@host>
- --src-path <path>
- --dst-host <user@host>
- --dst-path <path>
- --old-url <url>
- --new-url <url>

## Optional flags

- --config <file>
- --src-port <port>
- --dst-port <port>
- --src-key <path>
- --dst-key <path>
- --db-method <wpcli|mysqldump>
- --exclude <pattern> (repeatable)
- --skip-files
- --skip-db
- --skip-url-replace
- --dry-run
- --verbose
- --no-color
- --version
- -h, --help

## Environment variables

- WPCLONE_DEBUG=1
- WPCLONE_LOG=<path>

## Examples

Full migration:

```bash
./wpclone \
  --src-host deploy@old-server.com \
  --src-path /var/www/html \
  --dst-host deploy@new-server.com \
  --dst-path /var/www/html \
  --old-url https://old-site.com \
  --new-url https://new-site.com
```

Dry run:

```bash
WPCLONE_DEBUG=1 ./wpclone --config migration.conf --dry-run
```
