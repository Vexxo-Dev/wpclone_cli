---
layout: page
title: Publishing
permalink: /publishing/
---

# Publish Docs on GitHub Pages

This repository is ready to publish docs from the docs folder.

## Recommended setup (Deploy from branch)

1. Open repository Settings.
2. Go to Pages.
3. Source: Deploy from a branch.
4. Branch: main.
5. Folder: /docs.
6. Save.

GitHub will build and publish the site at:

https://vexxo-dev.github.io/wpclone_cli/

## Local preview (optional)

If you want to preview locally with Jekyll:

```bash
bundle exec jekyll serve --source docs
```

Then open http://127.0.0.1:4000

## After publishing

- Keep docs pages in docs/
- Update links in README when adding pages
- Use relative links between docs pages
