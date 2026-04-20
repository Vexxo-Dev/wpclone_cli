---
layout: page
title: Troubleshooting
permalink: /troubleshooting/
---

# Troubleshooting

## Discussions page returns 404

If this URL returns 404:

https://github.com/Vexxo-Dev/wpclone_cli/discussions/new?category=show-and-tell

Most common causes:

1. Discussions is not enabled for the repository.
2. The category slug show-and-tell does not exist.
3. You are not signed in to GitHub.
4. Repository visibility or permissions block access.

## Fix

1. Open repository Settings.
2. Enable Discussions in Features.
3. Open Discussions and create a category named Show and tell.
4. Use the Discussions home link first:
   https://github.com/Vexxo-Dev/wpclone_cli/discussions
5. After category exists, test the new discussion link again.

## Safe fallback link

Use this in README if category-specific link is unstable:

https://github.com/Vexxo-Dev/wpclone_cli/discussions
