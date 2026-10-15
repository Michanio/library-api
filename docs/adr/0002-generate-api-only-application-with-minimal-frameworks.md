# 2. Generate API-only application with minimal frameworks

Date: 2026-10-15
Status: Accepted

## Context

The task asks for a JSON API used by library staff, backed by PostgreSQL and started with `docker compose up`. The app needs to send reminder emails and run a periodic job. It has no UI, file uploads, real-time features or inbound email, and there is no deployment target beyond the reviewer's machine.

By default, Rails 8 generates a full-stack app with many frameworks and tools. Each unused one adds files, configuration and dependencies that a reviewer has to read past.

## Decision

The application was generated with:

```bash
rails new . --api -d postgresql -T --skip-kamal --skip-thruster \
  --skip-action-cable --skip-active-storage --skip-action-mailbox
```

Kept:

- **API-only mode (`--api`):** a slimmer middleware stack and `ActionController::API`. There are no views, assets or browser-specific middleware such as cookies, sessions or CSRF protection.
- **PostgreSQL (`-d postgresql`):** required by the task.
- **Action Mailer:** sends the return reminders. Mailer previews and logging satisfy the "no real emails" requirement.
- **Active Job with Solid Queue:** runs background jobs and the recurring reminder schedule using the database, without Redis.
- **Rails defaults for quality tooling:** RuboCop (rails-omakase), Brakeman, bundler-audit and the GitHub Actions CI workflow.

Skipped:

| Flag | Framework/tool | Reason |
|---|---|---|
| `-T` | Minitest | RSpec will be used instead (separate decision). |
| `--skip-kamal` | Kamal deployment | No deployment target; the app runs locally via Docker Compose. |
| `--skip-thruster` | Thruster HTTP proxy | TLS, HTTP/2 and static asset serving aren't needed for a local API. |
| `--skip-action-cable` | WebSockets | No real-time features. |
| `--skip-active-storage` | File uploads | Books and readers have no attachments. |
| `--skip-action-mailbox` | Inbound email | The app only sends email. |

## Alternatives considered

- **Full-stack default `rails new`:** includes views, assets, Hotwire and the skipped frameworks above, none of which the API uses. It means more code to review and maintain for no benefit.
- **Generating with defaults and removing parts later:** gets to the same place, but leaves a noisier history and risks leftover configuration.
- **A lighter framework (Sinatra, Roda, Hanami):** the task requires Ruby on Rails.

## Consequences

- (+) A smaller codebase and Gemfile, so the reviewer only sees what the task needs.
- (+) Faster boot and a smaller Docker image.
- (−) Adding a skipped framework later (for example, Active Storage for book covers) means adding the gem/railtie and its configuration by hand rather than through the generator.
- (−) The generated CI workflow has no test job until RSpec is set up.
- (−) The generated `Dockerfile` is production-oriented, so Docker Compose setup for development is still needed.
