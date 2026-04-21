# FAQ (/docs/faq)



## Is wpclone production ready? [#is-wpclone-production-ready]

It is usable for real migrations, but always run dry-run first and validate on staging before production.

## Can I migrate files only? [#can-i-migrate-files-only]

Yes.

```bash
./wpclone --config migration.conf --skip-db
```

## Can I migrate database only? [#can-i-migrate-database-only]

Yes.

```bash
./wpclone --config migration.conf --skip-files
```

## Can I skip URL replacement? [#can-i-skip-url-replacement]

Yes.

```bash
./wpclone --config migration.conf --skip-url-replace
```

## Where are logs saved? [#where-are-logs-saved]

Default is `./wpclone.log` unless changed with `WPCLONE_LOG`.
