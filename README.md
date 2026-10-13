# Dotted

A digital Bullet Journal — keyboard-driven rapid logging into one infinite timeline, collections, and an Upcoming screen for what is scheduled ahead. Built with **Rails 8**, **Hotwire** (Turbo + Stimulus), **Lexxy** (Action Text), and **SQLite** (Solid Queue/Cache/Cable). No React, no Node build step.

## License

Source-available under the **[O'Saasy License](LICENSE)** ([osaasy.dev](https://osaasy.dev)).

You may use, modify, and distribute the code freely. The one restriction: you **cannot offer Dotted (or a derivative) as a hosted SaaS** where the primary value is this app's functionality. Self-hosting for personal or team use is fine.

## Install with ONCE

Dotted ships as a single Docker image for [ONCE](https://github.com/basecamp/once), which manages HTTPS, updates, persistent storage, and backups.

You need a machine supported by ONCE, a hostname pointing at it, ports 80 and 443 free, and SMTP credentials. Sign-in uses emailed codes, so without SMTP nobody can log in.

```bash
curl https://get.once.com | sh
once deploy ghcr.io/spacepolice10/digibujo:latest --host dotted.example.com
```

Configure SMTP from ONCE's Email Settings screen. Dotted reads these variables directly:

| Variable | Purpose |
|----------|---------|
| `APP_HOST` | Allowed host and link host in emails |
| `DISABLE_SSL` | Set to `true` to serve plain HTTP (SSL is on by default) |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_DOMAIN` | Outgoing mail; mail delivery is off when `SMTP_ADDRESS` is unset |
| `MAILER_FROM_ADDRESS` | Sender address |
| `SECRET_KEY_BASE` | Required unless `RAILS_MASTER_KEY` is provided |

All state lives in `/rails/storage` (SQLite databases and uploads). The image's ONCE hooks (`hooks/pre-backup`, `hooks/post-restore`) snapshot and restore every production database with SQLite's online backup.

### Plain Docker

```bash
docker run --name dotted --publish 3000:80 --restart unless-stopped \
  --volume dotted_storage:/rails/storage \
  --env SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  --env DISABLE_SSL=true \
  ghcr.io/spacepolice10/digibujo:latest
```

### Kamal

Copy `config/deploy.yml.example` to `config/deploy.yml` and `.kamal/secrets.example` to `.kamal/secrets` (both ignored by git), then run `bin/kamal setup`.

### Releasing

Push a tag to publish `linux/amd64` and `linux/arm64` images to GitHub Container Registry:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

Set the package visibility to **Public** once so ONCE can pull without credentials.

## Setup

Prerequisites: Ruby (see `.ruby-version`), SQLite, [mise](https://mise.jdx.dev) recommended.

```bash
bin/setup
bin/dev
```

## Tests and CI

```bash
bin/rails test
bin/ci
```

CI runs Minitest, RuboCop, Brakeman, and dependency audits.

## Documentation

- **Framework reference (Rails, Turbo, Stimulus, Lexxy):** [docs/](docs/)
- **Agent/coding workflow (for AI assistants):** [AGENTS.md](AGENTS.md)

## Stack

| Layer | Choice |
|-------|--------|
| Backend | Rails 8.1, Ruby 4.0 |
| Frontend | Hotwire, Importmap, custom CSS (Propshaft) |
| Database | SQLite (+ FTS5 search) |
| Jobs | Solid Queue (in-process with Puma) |
| Deploy | ONCE, Docker, or Kamal; Thruster |
