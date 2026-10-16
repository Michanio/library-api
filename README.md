# Library API

A JSON API for library staff to manage books and their borrowing status. Built with Rails 8.1 (API-only), Ruby 4.0 and PostgreSQL 17.

> **Status:** work in progress. The project setup is complete (Docker Compose, RSpec, CI, ADRs), but the domain models and endpoints aren't implemented yet.

## Requirements

- Docker with the Compose plugin

You don't need Ruby or PostgreSQL on your machine. Everything runs in containers.

## Setup and running

> **Linux users:** the container runs as a user with UID/GID 1000 so that files it writes to the mounted source tree (`db/schema.rb`, logs) are owned by you. If your UID/GID differs (check with `id -u` and `id -g`), build the image with your IDs before the first start, and pass the same arguments whenever you rebuild:
>
> ```bash
> docker compose build --build-arg UID=$(id -u) --build-arg GID=$(id -g)
> ```
>
> Otherwise the container may be unable to write to the project directory. Docker Desktop (macOS, Windows) handles this automatically.

```bash
docker compose up
```

This builds the development image and starts three services:

| Service | What it does |
|---|---|
| `db` | PostgreSQL 17, with data kept in the `postgres_data` volume |
| `web` | Runs `bin/rails db:prepare` (creates and migrates the databases), then the Rails server on <http://localhost:3000> |
| `jobs` | Runs `bin/jobs` (the Solid Queue worker and recurring job scheduler). It starts once `web` is healthy. |

The app is up when <http://localhost:3000/up> returns 200.

The source code is bind-mounted into the containers, so code changes apply without a rebuild. After changing the `Gemfile`, rebuild the image:

```bash
docker compose build
```

To stop the app, run `docker compose down`. Add `-v` to also delete the database volume.

### Common commands

All commands run inside the `web` container:

```bash
docker compose exec web bin/rails console
docker compose exec web bin/rails db:migrate   # also updates db/schema.rb and db/queue_schema.rb
docker compose exec web bin/rails routes
```

## Running tests

The test suite uses RSpec, FactoryBot and shoulda-matchers.

```bash
docker compose exec web bin/rails db:test:prepare        # once, and after new migrations
docker compose exec web bundle exec rspec                # whole suite
docker compose exec web bundle exec rspec spec/path_spec.rb:42   # a single example
```

Specs run in the same container as the app, against the separate `library_api_test` database. Each example runs inside a database transaction that's rolled back afterwards, so no cleanup gem is needed.

## Code quality and CI

```bash
docker compose exec web bin/rubocop               # lint (rubocop-rails-omakase)
docker compose exec web bin/brakeman --no-pager   # security static analysis
docker compose exec web bin/bundler-audit         # known vulnerabilities in gems
docker compose exec web bin/ci                    # all of the above plus RSpec (steps in config/ci.rb)
```

GitHub Actions (`.github/workflows/ci.yml`) runs Brakeman, bundler-audit, RuboCop and RSpec against a PostgreSQL service on every pull request and every push to `main`.

## Architecture

### Application setup

- **API-only Rails** generated with a minimal set of frameworks: no Action Cable, Active Storage, Action Mailbox, Kamal or Thruster ([ADR 2](docs/adr/0002-generate-api-only-application-with-minimal-frameworks.md)).
- **Docker Compose runs the app in development mode** using `Dockerfile.dev`. The generated production `Dockerfile` is kept unchanged as a starting point for a real deployment ([ADR 3](docs/adr/0003-run-the-app-in-development-mode-via-docker-compose.md)).
- **Background jobs use Solid Queue**, backed by PostgreSQL rather than Redis. Its tables live in a separate `queue` database (schema in `db/queue_schema.rb`), as in production. Recurring jobs are defined in `config/recurring.yml`. In tests, Active Job uses the test adapter.
- **Emails** (return reminders) will use Action Mailer. Nothing will actually be delivered: reminders will be viewable through mailer previews and in the log.

### Domains

Code is grouped by business domain under `app/domains/`, not only by technical role ([ADR 4](docs/adr/0004-organize-code-into-domains-with-public-interfaces.md)):

| Domain | Owns | Responsibility |
|---|---|---|
| `Catalog` | `books` | Book identity: serial number, title, author |
| `Readers` | `readers` | Library card number, full name, email |
| `Lending` | `borrowings` | Borrowing and returning, due dates, borrowing history, reminders |

- Each domain owns its tables and models, and exposes a public interface as methods on its module (`app/domains/<domain>.rb`). These methods return value objects, not Active Record models.
- Domains refer to each other's records by ID only, never through associations. `Lending` depends on `Catalog` and `Readers`, never the other way round.
- Controllers in `app/controllers` form a separate HTTP layer. They call public interfaces only, and they combine data from several domains when an endpoint needs it.

### Planned data model

- A book's status (available or borrowed) is derived from its open borrowing (`returned_at IS NULL`). A partial unique index ensures a book has at most one open borrowing.
- Loans last 30 days. One daily recurring job sends reminders 3 days before the due date and on the due date, instead of scheduling a delayed job per borrowing.

## Architecture decision records

Significant design decisions are recorded in [`docs/adr/`](docs/adr/):

1. [Record architecture decisions](docs/adr/0001-record-architecture-decisions.md)
2. [Generate API-only application with minimal frameworks](docs/adr/0002-generate-api-only-application-with-minimal-frameworks.md)
3. [Run the app in development mode via Docker Compose](docs/adr/0003-run-the-app-in-development-mode-via-docker-compose.md)
4. [Organize code into domains with public interfaces](docs/adr/0004-organize-code-into-domains-with-public-interfaces.md)

New ADRs are created with a small generator:

```bash
docker compose exec web bin/rails g adr "Title" --status=Accepted
```

## Limitations and ideas for improvement

- **No authentication or authorization.** The task is scoped to internal staff use.
- **The Compose setup isn't production-ready.** It uses development server settings, hard-coded database credentials and no TLS.
- **Domain boundaries are enforced only by convention.** [packwerk](https://github.com/Shopify/packwerk) could check them statically in CI.
- **Operations that span domains are coordinated in controllers**, for example refusing to delete a borrowed book. As the app grows, application services or domain events would be a better fit.
