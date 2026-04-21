# Usage (/docs/usage)



## Usage [#usage]

General syntax:

```text
wpclone [OPTIONS]
wpclone --config migration.conf
```

## Required options [#required-options]

* \--src-host
* \--src-path
* \--dst-host
* \--dst-path
* \--old-url
* \--new-url

## Common options [#common-options]

* \--config
* \--db-method wpcli or mysqldump
* \--skip-files
* \--skip-db
* \--skip-url-replace
* \--exclude
* \--dry-run
* \--verbose

## Environment variables [#environment-variables]

* `WPCLONE_DEBUG=1` enable debug output.
* `WPCLONE_LOG=<path>` customize log file path.

## Examples [#examples]

### Full migration [#full-migration]

```bash
./wpclone \
  --src-host deploy@old-server.com \
  --src-path /var/www/html \
  --dst-host deploy@new-server.com \
  --dst-path /var/www/html \
  --old-url https://old-site.com \
  --new-url https://new-site.com
```

### Files only [#files-only]

```bash
./wpclone --config migration.conf --skip-db
```

### Database only [#database-only]

```bash
./wpclone --config migration.conf --skip-files
```

### Dry run [#dry-run]

```bash
WPCLONE_DEBUG=1 ./wpclone --config migration.conf --dry-run
```

## Recommended migration flow [#recommended-migration-flow]

1. Prepare migration.conf with source and destination values
2. Run dry-run and review output
3. Run real migration
4. Verify site URL and admin login
5. Flush cache if needed
