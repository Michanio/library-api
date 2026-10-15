# 3. Run the app in development mode via Docker Compose

Date: 2026-10-15
Status: Accepted

## Context

The task requires that `docker compose up` starts a working application backed by PostgreSQL. The reviewer will run it locally to try out the API and inspect reminder emails. The task accepts logging the email payload or a mailer preview instead of real delivery.

The same setup is also the day-to-day development environment: there is no local PostgreSQL, and specs run inside the container.

Rails generates a production-oriented `Dockerfile`. That image doesn't include development or test gems, needs `SECRET_KEY_BASE` or `config/master.key`, and serves the code that was baked in at build time.

## Decision

`compose.yaml` runs the application in the **development** environment, using a separate `Dockerfile.dev`:

- **`db`:** PostgreSQL 17 with a named volume and a `pg_isready` health check.
- **`web`:** runs `bin/rails db:prepare`, then the Rails server on port 3000. It's marked healthy once `/up` responds.
- **`jobs`:** runs `bin/jobs` (Solid Queue dispatcher, worker and scheduler). It starts only after `web` is healthy, because `web` creates the queue tables.

Supporting choices:

- **Source code is bind-mounted** into the containers, and gems are installed at image build time. Code changes apply without a rebuild. Gemfile changes need `docker compose build`.
- **The container runs as a user with UID/GID 1000** (configurable with build args), so files it creates in the mounted tree (`db/schema.rb`, logs) are owned by the host user.
- **Database connection settings come from `DB_HOST`, `DB_USERNAME` and `DB_PASSWORD`.** When they're unset, the libpq defaults apply, so the app can still run against a local PostgreSQL.
- **Solid Queue runs in development too, using a separate `queue` database**, the same layout Rails generates for production. Jobs are processed by the `jobs` service, as in production, rather than inline in the web process. The choice of Solid Queue itself is covered by a separate decision.
- **`RAILS_ENV` isn't set in Compose.** `spec/rails_helper.rb` sets `RAILS_ENV` to `test` only when it's unset, so specs run against the test database from the same container.

The generated production `Dockerfile` is kept unchanged as a starting point for a real deployment.

## Alternatives considered

- **Running Compose in production mode with the generated `Dockerfile`:** closer to a real deployment, but the reviewer would need a secret key. It also disables mailer previews, has no test gems for running specs, and needs a rebuild after every code change.
- **One multi-stage `Dockerfile` with development and production targets:** avoids a second file, but makes the generated production Dockerfile harder to read and diff against Rails defaults.
- **Running Solid Queue inside Puma (`SOLID_QUEUE_IN_PUMA`):** one container fewer, but it hides the worker process and differs from how jobs would run in production.
- **Solid Queue tables in the primary database:** one database fewer, but it differs from the production layout and mixes framework tables into `db/schema.rb`.
- **Local PostgreSQL:** depends on each machine's installation and credentials, which is exactly what failed during setup.

## Consequences

- (+) `docker compose up` is the only setup step, with no secrets or local services needed.
- (+) Mailer previews and detailed error pages are available to the reviewer.
- (+) Development, test and CI all use PostgreSQL, and the queue database layout matches production.
- (−) The Compose setup isn't production-ready (development server settings, hard-coded credentials, no TLS). This is acceptable for a recruitment task and noted in the README.
- (−) Commands are longer (`docker compose exec web ...`).
- (−) Gemfile changes need an image rebuild.
