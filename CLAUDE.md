# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Recruitment task: an API-only Rails 8.1 app (Ruby 4.0, PostgreSQL) for library staff to manage books and their borrowing status. No authentication/authorization.

Requirements from the task brief (not stored elsewhere in the repo):
- Book: unique six-digit serial number, title, author, whether it is currently borrowed, when and by whom.
- Reader: unique six-digit library card number, full name, unique email.
- Endpoints: add a book, delete a book, list all books with available/borrowed status, show a book with its full borrowing history (borrow date, return date, reader data), update a book's status (borrowed/available).
- Loans last 30 days. Readers get an email reminder 3 days before the due date and on the due date. Real delivery isn't needed; logging the payload or a mailer preview is enough.
- `docker compose up` must start a working app. A README should explain key design decisions, limitations and ideas for improvement.

## Commands

Development runs in Docker Compose (`compose.yaml`, `Dockerfile.dev`); there is no local PostgreSQL. Services: `db` (Postgres 17), `web` (runs `db:prepare`, then the server on :3000), `jobs` (`bin/jobs`, Solid Queue).

```bash
docker compose up                                    # start db, web, jobs
docker compose exec web bin/rails db:migrate         # also dumps db/schema.rb and db/queue_schema.rb
docker compose exec web bin/rails db:test:prepare    # loads db/schema.rb into the test DB; rerun after migrations
docker compose exec web bundle exec rspec            # all specs
docker compose exec web bundle exec rspec spec/path_spec.rb:LINE
docker compose exec web bin/rubocop                  # lint (rubocop-rails-omakase)
docker compose exec web bin/brakeman --no-pager
docker compose exec web bin/ci                       # steps from config/ci.rb
docker compose build                                 # after Gemfile changes
```

Don't set `RAILS_ENV` in `compose.yaml`: `spec/rails_helper.rb` uses `ENV["RAILS_ENV"] ||= "test"`, so a global value would run the specs against the development database.

Tests use RSpec with FactoryBot (`create(:book)` syntax) and shoulda-matchers. Support files live in `spec/support/`. CI (`.github/workflows/ci.yml`) runs Brakeman, bundler-audit, RuboCop and RSpec against a Postgres service.

## Architecture notes

- Generated with `rails new . --api -d postgresql -T --skip-kamal --skip-thruster --skip-action-cable --skip-active-storage --skip-action-mailbox`. Don't reintroduce the skipped frameworks without a reason.
- Background jobs use Solid Queue, and recurring jobs are defined in `config/recurring.yml`. Solid Queue uses a separate `queue` database in development and production (`config/database.yml`; the schema is `db/queue_schema.rb`). In test, Active Job uses the test adapter.
- Code is organized into domains under `app/domains/` (`Catalog`, `Readers`, `Lending`), each owning its tables and exposing a public interface on the domain module; controllers in `app/controllers` are a separate HTTP layer that composes domains. See ADR 0004 for the rules. Every interface method is a one-liner delegating to a service object named after the operation (`Catalog.add_book` → `Catalog::AddBook.call`, defined as `def self.call(...) = new(...).call`), even for trivial operations; edge cases are specced on the service object, the interface spec only covers the happy path and error types. Domain model specs need an explicit `type: :model` for shoulda-matchers.
- The API contract is `docs/openapi.yaml` (OpenAPI 3.1, validated with `openapi_first`, see ADR 0005). Update it in the same change as any endpoint, parameter, response or error. Responses are plain JSON with snake_case keys; collections are wrapped (`{"books": [...]}`); six-digit identifiers are strings. Errors are RFC 9457 `application/problem+json` with `urn:library-api:problem:*` types (400 schema mismatch, 404, 409 state conflict, 422 domain rule).
- HTTP layer conventions: actions read JSON bodies through `request_body` (openapi_first's parsed body, already validated against the contract), not strong parameters. Response documents are built by serializers in `app/serializers/`, which render timestamps with `.utc.iso8601` because `config.time_zone` isn't UTC. Domain errors become problem details via `rescue_from` in `ApplicationController`, using the `ProblemDetails` builders. Request specs should cover every documented response, since the contract test integration validates each one.
- Books are addressed by serial number in URLs. Borrow/return are action endpoints (`POST /books/:serial_number/borrow|return`). Books are soft-deleted; serial numbers are never reused. There are no reader endpoints yet (planned for later); readers come from seed data.
- Authors are authority records (ADR 0007): `Catalog` owns `authors` (name unique case-insensitively) and `book_authors` (many-to-many, at least one author per book). The API refers to authors by ID (`author_ids`); there are no author endpoints yet, so authors come from seed data. Books are soft-deleted via `deleted_at` (ADR 0006); always query them through the `active` scope (not deleted; unrelated to lending availability), never a `default_scope`.
- `Readers` owns `readers` (six-digit card number, full name, email unique case-insensitively and normalized to lowercase). Its interface: `find_reader(library_card_number)` and `list_readers(ids:)`.
- `Lending` owns `borrowings` (ADR 0008). A book's status is derived from its current borrowing (`returned_at IS NULL`, the `current` scope), enforced by a partial unique index; there is no status column. Loans last 30 days; `due_on` is a date in the library's time zone (`config.time_zone = "Europe/Warsaw"`), while timestamps are returned in UTC. Interface: `borrow_book`, `return_book`, `current_borrowings(book_ids:)` (a hash by book ID) and `borrowing_history(book_id:)`.
- Planned, not yet implemented: reminders come from one daily recurring job rather than delayed jobs per borrowing.

## Conventions

- Significant design decisions (real trade-offs) are recorded as ADRs in `docs/adr/` as numbered Markdown files (`0001-title.md`) with Context / Decision / Alternatives considered / Consequences. Create them with `bin/rails g adr "Title" [--status=Accepted]` (`lib/generators/adr/`). Read the existing ADRs before proposing changes, flag any proposal that contradicts an accepted ADR, and propose a new ADR when a decision has real trade-offs.
- The user prefers to run generators (`rails g ...`) themselves. Provide the command instead of running it unless asked.
- Before finishing a change, run `bin/rubocop` and the test suite.
