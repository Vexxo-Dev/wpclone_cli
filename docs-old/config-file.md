---
layout: page
title: Config File
permalink: /config-file/
---

# Config File

Copy migration.conf.example to your own config file and set values:

```bash
cp migration.conf.example migration.conf
```

Run with:

```bash
./wpclone --config migration.conf
```

## Example

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

## Notes

- Format is key=value
- Lines starting with # are comments
- EXCLUDE can be repeated
- Unknown keys are ignored with a warning
