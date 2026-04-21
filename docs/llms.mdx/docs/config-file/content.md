# Config File (/docs/config-file)



Use a config file to make migrations repeatable.

## Create config [#create-config]

```bash
cp migration.conf.example migration.conf
```

## Run with config [#run-with-config]

```bash
./wpclone --config migration.conf
```

## Example [#example]

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

## Notes [#notes]

* Use `key=value` format.
* Lines starting with `#` are comments.
* `EXCLUDE` can be repeated for multiple patterns.
* Unknown keys are ignored with warning output.
