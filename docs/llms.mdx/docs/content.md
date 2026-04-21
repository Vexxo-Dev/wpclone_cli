# wpclone Documentation (/docs)





Welcome to the official documentation for wpclone.

wpclone is a Bash CLI that automates WordPress migration between servers using SSH, rsync, and WP-CLI (with mysqldump/mysql fallback).

## What you can do with wpclone [#what-you-can-do-with-wpclone]

* Sync files
* Export and import database
* Replace old URL with new URL
* Validate first with dry run

## Quick Start [#quick-start]

Run this first to validate your migration safely:

```bash
./wpclone --config migration.conf --dry-run
```

Then run the same command without dry run.

## Documentation [#documentation]

<Cards className="gap-x-5 gap-y-4 md:gap-x-6 md:gap-y-5">
  <Card icon="<BookOpen />" title="Getting Started" href="/docs/getting-started">
    Install prerequisites and run your first dry-run migration safely.
  </Card>

  <Card icon="<Compass />" title="Usage" href="/docs/usage">
    Learn the complete command flow, flags, and recommended execution order.
  </Card>

  <Card icon="<Settings />" title="Config File" href="/docs/config-file">
    Understand every key in migration.conf with real-world examples.
  </Card>

  <Card icon="<GitCompareArrows />" title="Migration Flow" href="/docs/migration-flow">
    Follow a repeatable step-by-step process from source to destination.
  </Card>

  <Card icon="<Shield />" title="Security" href="/docs/security-best-practices">
    Apply practical hardening and least-privilege patterns for production.
  </Card>

  <Card icon="<Wrench />" title="Troubleshooting" href="/docs/troubleshooting">
    Resolve common SSH, rsync, database, and URL replacement issues quickly.
  </Card>

  <Card icon="<CircleHelp />" title="FAQ" href="/docs/faq">
    Find direct answers for migration edge cases and operational questions.
  </Card>

  <Card icon="<MessageSquare />" title="Support and Discussions" href="/docs/support">
    Get help, share success stories, and ask migration-specific questions.
  </Card>

  <Card icon="<FolderGit2 />" title="GitHub Repository" href="https://github.com/Vexxo-Dev/wpclone_cli">
    Browse source code, releases, and contribution guidelines.
  </Card>

  <Card icon="<MessagesSquare />" title="Discussions" href="https://github.com/Vexxo-Dev/wpclone_cli/discussions">
    Open or join community discussions around workflow and troubleshooting.
  </Card>
</Cards>

## Recommended migration sequence [#recommended-migration-sequence]

1. Prepare `migration.conf`.
2. Run dry-run.
3. Run full migration.
4. Verify site and admin.
5. Share issues or success notes in Discussions.
