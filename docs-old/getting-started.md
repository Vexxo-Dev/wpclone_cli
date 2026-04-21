---
layout: page
title: Getting Started
permalink: /getting-started/
---

# Getting Started

## Requirements

Local machine:

- bash 4+
- ssh
- rsync
- scp

Source server:

- ssh access
- wp-cli recommended, or mysqldump

Destination server:

- ssh access
- wp-cli recommended, or mysql
- WordPress already installed

## Run from GitHub directly

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Vexxo-Dev/wpclone_cli/main/wpclone.sh) \
  --src-host deploy@old-server.com \
  --src-path /var/www/html \
  --dst-host deploy@new-server.com \
  --dst-path /var/www/html \
  --old-url https://old-site.com \
  --new-url https://new-site.com
```

## Install locally

```bash
curl -fsSL https://raw.githubusercontent.com/Vexxo-Dev/wpclone_cli/main/wpclone.sh -o wpclone
chmod +x wpclone
sudo mv wpclone /usr/local/bin/wpclone
wpclone --version
```
