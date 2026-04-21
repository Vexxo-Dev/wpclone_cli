# Security Best Practices (/docs/security-best-practices)



## SSH and access [#ssh-and-access]

* Use SSH keys, not password prompts.
* Use least-privileged deploy users.
* Restrict access by IP when possible.

## Dry-run first [#dry-run-first]

Always run:

```bash
./wpclone --config migration.conf --dry-run
```

This catches missing paths and auth issues before any changes.

## Protect sensitive data [#protect-sensitive-data]

* Never commit real `.conf` files with secrets.
* Keep `migration.conf.example` generic.
* Redact hosts and credentials when sharing logs.

## Validate target environment [#validate-target-environment]

* Ensure destination has working `wp-config.php`.
* Verify PHP and DB versions are compatible.
* Confirm sufficient disk space before migration.

## Post-migration checks [#post-migration-checks]

* Verify homepage and wp-admin.
* Check media and permalinks.
* Check plugin/theme critical features.
