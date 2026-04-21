# Migration Flow (/docs/migration-flow)



## High-level flow [#high-level-flow]

1. Validate input options and dependencies.
2. Transfer files with rsync (unless skipped).
3. Export database on source.
4. Import database on destination.
5. Run URL replacement.
6. Perform post-migration tasks.

## Detailed steps [#detailed-steps]

### 1) Validation [#1-validation]

* Checks required options.
* Checks local tools like `ssh` and `rsync`.
* Checks remote tools and switches DB method if needed.

### 2) File transfer [#2-file-transfer]

* Uses rsync over SSH.
* Supports `--exclude` patterns.
* Can be skipped with `--skip-files`.

### 3) Database transfer [#3-database-transfer]

* Uses WP-CLI by default.
* Falls back to mysqldump/mysql if WP-CLI unavailable.
* Can be skipped with `--skip-db`.

### 4) URL replacement [#4-url-replacement]

* Uses `wp search-replace` for safe serialized replacement.
* Can be skipped with `--skip-url-replace`.

### 5) Finalization [#5-finalization]

* Cache flush
* Rewrite flush
* Permissions hardening
