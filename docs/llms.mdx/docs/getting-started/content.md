# Getting Started (/docs/getting-started)



## Requirements [#requirements]

Local machine:

* Bash 4+
* ssh
* rsync
* scp

Source server:

* SSH access
* WP-CLI recommended, or mysqldump

Destination server:

* SSH access
* WP-CLI recommended, or mysql
* Existing WordPress installation

## Run from GitHub (one-liner) [#run-from-github-one-liner]

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Vexxo-Dev/wpclone_cli/main/wpclone.sh) \
  --src-host deploy@old-server.com \
  --src-path /var/www/html \
  --dst-host deploy@new-server.com \
  --dst-path /var/www/html \
  --old-url https://old-site.com \
  --new-url https://new-site.com
```

## Install locally [#install-locally]

```bash
curl -fsSL https://raw.githubusercontent.com/Vexxo-Dev/wpclone_cli/main/wpclone.sh -o wpclone
chmod +x wpclone
sudo mv wpclone /usr/local/bin/wpclone
wpclone --version
```

## First safe run [#first-safe-run]

```bash
./wpclone --config migration.conf --dry-run
```

After validating output, run the same command without `--dry-run`.
