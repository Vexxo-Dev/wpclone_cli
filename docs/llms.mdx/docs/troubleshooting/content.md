# Troubleshooting (/docs/troubleshooting)



## Discussions page shows 404 [#discussions-page-shows-404]

If category-specific URL fails, open Discussions home first:

[https://github.com/Vexxo-Dev/wpclone\_cli/discussions](https://github.com/Vexxo-Dev/wpclone_cli/discussions)

Possible reasons:

* Not signed in to GitHub.
* Direct category link changed.
* Temporary repo visibility or permission issue.

## SSH connection fails [#ssh-connection-fails]

Check:

* Host and user in `--src-host` and `--dst-host`.
* SSH key permissions.
* Firewall and port settings.

Test manually:

```bash
ssh deploy@old-server.com
```

## wp command not found [#wp-command-not-found]

wpclone automatically falls back to mysqldump/mysql when WP-CLI is missing.

To force fallback mode:

```bash
./wpclone --config migration.conf --db-method mysqldump
```

## Migration failed unexpectedly [#migration-failed-unexpectedly]

Run with debug mode:

```bash
WPCLONE_DEBUG=1 ./wpclone --config migration.conf --dry-run
```

Then inspect log output and re-run.
