# Contributing to wpclone

Thank you for your interest in contributing! wpclone is in early development and
all contributions — big or small — are welcome.

## Getting Started

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/youruser/wpclone.git`
3. Create a **feature branch**: `git checkout -b feat/my-feature`
4. Make your changes
5. **Test** thoroughly (see Testing section below)
6. **Commit** with a clear, conventional message: `git commit -m "feat: add direct SSH tunnelling"`
7. Open a **Pull Request**

## Development Guidelines

### Code Style
- Pure Bash, no external dependencies beyond `ssh`, `rsync`, `scp`
- Use `set -euo pipefail` and `IFS=$'\n\t'` for safety
- Quote all variables: `"$var"` not `$var`
- Use `readonly` for constants
- Use `local` for all variables inside functions
- Run `shellcheck wpclone.sh` before submitting (install: `apt install shellcheck`)

### Commit Messages
Follow [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` — new feature
- `fix:` — bug fix
- `docs:` — documentation only
- `test:` — tests
- `refactor:` — code refactoring
- `chore:` — maintenance

## Testing

We use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

```bash
# Install BATS
git clone https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh /usr/local

# Run tests
bats tests/
```

For integration testing, two SSH-accessible servers (or Docker containers) are needed.
A `docker-compose.yml` for local testing environments is on the roadmap.

## Reporting Issues

When reporting a bug, please include:
- The exact command you ran (redact passwords/keys)
- The contents of `wpclone.log`
- Output of `bash --version` on your local machine
- SSH server OS and version (Ubuntu 22.04, etc.)
- Whether WP-CLI is installed on source/destination

## Feature Ideas

Before opening a PR for a large feature, please open an issue first to discuss it.

Current high-priority areas:
- Direct server-to-server transfer (without local staging)
- BATS test suite
- `--backup` / rollback support
- Docker-based testing environment

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
