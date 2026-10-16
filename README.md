# Library API

A JSON API for library staff to manage books and their borrowing status: add and delete books, list them with their status, show a book's full borrowing history, lend and return books, and send readers return reminders. Built with Rails 8.1 (API-only), Ruby 4.0 and PostgreSQL 17.

- **Contract:** [`docs/openapi.yaml`](docs/openapi.yaml) (OpenAPI 3.1). Every request is validated against it, and the test suite fails unless every documented response is exercised. With the app running, browse and try it at <http://localhost:3000/docs>.
- **Design decisions:** [`docs/adr/`](docs/adr/), summarised [below](#architecture-decision-records).

## Requirements

- Docker with the Compose plugin

You don't need Ruby or PostgreSQL on your machine. Everything runs in containers.

## Running the app

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
| `web` | Runs `bin/rails db:prepare` (creates and migrates the databases, and loads the seed data into a new database), then the Rails server on <http://localhost:3000> |
| `jobs` | Runs `bin/jobs`: the Solid Queue worker and the scheduler for the daily reminder job. It starts once `web` is healthy, and logs to the console, including the reminder emails. |

The app is up when <http://localhost:3000/up> returns 200. Interactive API docs (Swagger UI) are at <http://localhost:3000/docs>.

The source code is bind-mounted into the containers, so code changes apply without a rebuild (restart `web` after changing `docs/openapi.yaml`, which is loaded at boot). After changing the `Gemfile`, rebuild the image with `docker compose build`.

To stop the app, run `docker compose down`. Add `-v` to also delete the database volume.

## Trying the API

### Seed data

There are no endpoints for authors or readers yet (see [limitations](#limitations-and-ideas-for-improvement)), so the seed data provides them. On a new database, the IDs are:

| Author ID | Name | | Author ID | Name |
|---|---|---|---|---|
| 1 | Frank Herbert | | 7 | Fyodor Dostoevsky |
| 2 | Ursula K. Le Guin | | 8 | David Thomas |
| 3 | Stanisław Lem | | 9 | Andrew Hunt |
| 4 | Andrzej Sapkowski | | 10 | Martin Fowler |
| 5 | George Orwell | | 11 | Kent Beck |
| 6 | Jane Austen | | 12 | Sandi Metz |

| Library card | Reader | Email |
|---|---|---|
| 000001 | Anna Kowalska | anna.kowalska@example.com |
| 000002 | Jan Nowak | jan.nowak@example.com |
| 000003 | Jane Doe | jane.doe@example.com |
| 004217 | John Smith | john.smith@example.com |
| 123456 | Maria Wiśniewska | maria.wisniewska@example.com |

Run `docker compose exec web bin/rails db:seed` to load them into an existing database. It's safe to run more than once.

### Endpoints

| Brief requirement | Endpoint |
|---|---|
| Add a new book | `POST /books` |
| Delete a book | `DELETE /books/{serial_number}` |
| List all books with their status | `GET /books` |
| Show a book with its full borrowing history | `GET /books/{serial_number}` |
| Update the book status: borrowed | `POST /books/{serial_number}/borrow` |
| Update the book status: available | `POST /books/{serial_number}/return` |

Books are addressed by their six-digit serial number. Six-digit identifiers are strings, so leading zeros are kept.

### Walkthrough

```bash
# Add a book with two authors
curl -i -X POST localhost:3000/books -H 'Content-Type: application/json' \
  -d '{"serial_number": "000123", "title": "The Pragmatic Programmer", "author_ids": [8, 9]}'

# Lend it to John Smith for 30 days
curl -X POST localhost:3000/books/000123/borrow -H 'Content-Type: application/json' \
  -d '{"library_card_number": "004217"}'

# List all books: status, and who borrowed each one and when
curl localhost:3000/books

# Return it, then show the book with its borrowing history
curl -X POST localhost:3000/books/000123/return
curl localhost:3000/books/000123

# Delete it (refused with 409 while the book is borrowed)
curl -i -X DELETE localhost:3000/books/000123
```

A borrowed book looks like this:

```json
{
  "serial_number": "000123",
  "title": "The Pragmatic Programmer",
  "authors": [{ "id": 9, "name": "Andrew Hunt" }, { "id": 8, "name": "David Thomas" }],
  "status": "borrowed",
  "current_borrowing": {
    "reader": { "library_card_number": "004217", "full_name": "John Smith", "email": "john.smith@example.com" },
    "borrowed_at": "2026-10-16T20:46:52Z",
    "due_on": "2026-11-15"
  }
}
```

Errors are [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem details (`application/problem+json`), with a `type` to branch on and, for invalid input, a JSON Pointer to each offending field:

```json
{
  "type": "urn:library-api:problem:validation-failed",
  "title": "Validation failed",
  "status": 422,
  "detail": "The book could not be saved.",
  "errors": [{ "pointer": "/serial_number", "detail": "has already been taken" }]
}
```

| Status | When |
|---|---|
| 400 `invalid-request` | The request doesn't match the contract (missing or unknown field, wrong type, malformed serial number) |
| 404 | No such book, or the book was deleted |
| 409 `book-borrowed` / `book-not-borrowed` | Borrowing or deleting a borrowed book; returning a book that isn't borrowed |
| 422 `validation-failed` | Well-formed, but a rule says no: serial number taken, unknown author ID or library card number |

The full contract, with every schema and example, is [`docs/openapi.yaml`](docs/openapi.yaml). In development, <http://localhost:3000/docs> shows it in Swagger UI, where "Try it out" sends real requests to the running app. The page is served by Rails in development only and loads Swagger UI from a CDN, so the browser needs internet access.

### Return reminders

Loans last 30 days. Readers get an email 3 days before the due date and on the due date. A recurring job runs every day at 08:00 Europe/Warsaw. No email is actually sent: each one is written to the log instead.

- **Previews:** <http://localhost:3000/rails/mailers/lending/reminder_mailer> shows the due-soon, due-today and overdue (sent late) emails.
- **Real run:** make a loan due in 3 days and run the job now instead of waiting for 08:00:

  ```bash
  curl -X POST localhost:3000/books/000123/borrow -H 'Content-Type: application/json' -d '{"library_card_number": "004217"}'
  docker compose exec web bin/rails runner \
    'Lending::Borrowing.current.update_all(due_on: Date.current + 3); Lending::SendRemindersJob.perform_later'
  docker compose logs jobs | grep -A12 LogDelivery
  ```

  Running the job again sends nothing new, because each reminder is recorded on the borrowing when it's sent.

## Running tests

The test suite uses RSpec, FactoryBot and shoulda-matchers.

```bash
docker compose exec web bin/rails db:test:prepare        # once, and after new migrations
docker compose exec web bundle exec rspec                # whole suite
docker compose exec web bundle exec rspec spec/path_spec.rb:42   # a single example
docker compose exec web env OPENAPI_COVERAGE=strict bundle exec rspec   # as in CI
```

Specs run in the same container as the app, against the separate `library_api_test` database. Each example runs inside a database transaction that's rolled back afterwards, so no cleanup gem is needed.

Request specs are contract tests: [`openapi_first`](https://github.com/ahx/openapi_first) validates every request and response they make against `docs/openapi.yaml` and fails the spec on a mismatch. With `OPENAPI_COVERAGE=strict` (set in CI), the run also fails unless every documented request and response was exercised. Without it, uncovered parts of the contract only print a warning, so a single spec file can still be run on its own.

## Code quality and CI

```bash
docker compose exec web bin/rubocop               # lint (rubocop-rails-omakase)
docker compose exec web bin/brakeman --no-pager   # security static analysis
docker compose exec web bin/bundler-audit         # known vulnerabilities in gems
docker compose exec web bin/ci                    # all of the above plus RSpec (steps in config/ci.rb)
```

GitHub Actions (`.github/workflows/ci.yml`) runs Brakeman, bundler-audit, RuboCop and RSpec (with strict contract coverage) against a PostgreSQL service on every pull request and every push to `main`.

## Architecture

### Domains

Code is grouped by business domain under `app/domains/` ([ADR 4](docs/adr/0004-organize-code-into-domains-with-public-interfaces.md)):

| Domain | Owns | Responsibility |
|---|---|---|
| `Catalog` | `books`, `authors`, `book_authors` | Books (serial number, title), their authors, soft deletion |
| `Readers` | `readers` | Library card number, full name, email |
| `Lending` | `borrowings` | Borrowing and returning, due dates, borrowing history, reminders |

- Each domain owns its tables and exposes a public interface as methods on its module (`app/domains/catalog.rb`, ...). Each method is a one-line delegation to a service object (`Catalog.add_book` calls `Catalog::AddBook`) and returns value objects (`Data.define`), never Active Record models.
- Domains refer to each other's records by ID, never through associations. `Lending` depends on `Catalog` and `Readers`, never the other way round. Database foreign keys still protect integrity.
- Controllers in `app/controllers` form a separate HTTP layer. They call public interfaces only, combine data from several domains (a book's status and history come from `Lending`, reader details from `Readers`), and coordinate operations that span domains, such as refusing to delete a borrowed book.

### Request handling

1. `ApplicationController` validates every request against `docs/openapi.yaml` before the action runs. A mismatch is answered with a 400 problem, so actions can rely on the documented shape and read the parsed body (`request_body`) instead of strong parameters ([ADR 5](docs/adr/0005-use-plain-json-with-rfc-9457-errors-and-an-openapi-contract.md)).
2. The action calls domain interfaces. Domain errors (`Catalog::BookNotFound`, `Lending::BookAlreadyBorrowed`, ...) are turned into problem details with `rescue_from`.
3. Serializers in `app/serializers` build the response documents. Timestamps are rendered in UTC; the app's time zone (Europe/Warsaw) is only used for calendar dates.

### Data model

- **Books** are identified by a unique six-digit serial number, checked by the database as well as the model. Deleting a book sets `deleted_at` and hides it from the API, but keeps its borrowing history. Serial numbers are never reused ([ADR 6](docs/adr/0006-soft-delete-books-to-keep-borrowing-history.md)).
- **Authors** are authority records linked to books many-to-many, instead of a free-text `author` field, so the same author can't be spelt several ways. `POST /books` refers to authors by ID ([ADR 7](docs/adr/0007-model-authors-as-authority-records-linked-to-books.md)).
- **Readers** have a unique six-digit library card number and an email that's unique regardless of case.
- **Book status isn't stored.** A book is borrowed if and only if it has a borrowing with `returned_at IS NULL`, and a partial unique index allows at most one per book, even under concurrent requests. That borrowing says who borrowed the book and when; all borrowings together are the history ([ADR 8](docs/adr/0008-derive-book-status-from-the-open-borrowing.md)).
- **Loans last 30 days.** `due_on` is a calendar date in the library's time zone, so a loan made just after midnight isn't dated the previous day.
- **Reminders** come from one daily recurring job, not from delayed jobs per loan. Each borrowing records when each of its two reminders was sent, so a second run sends nothing new and a missed day is caught up on the next run ([ADR 9](docs/adr/0009-send-return-reminders-from-one-daily-job-that-records-what-was-sent.md)).

### Application setup

- **API-only Rails** generated with a minimal set of frameworks: no Action Cable, Active Storage, Action Mailbox, Kamal or Thruster ([ADR 2](docs/adr/0002-generate-api-only-application-with-minimal-frameworks.md)).
- **Docker Compose runs the app in development mode** using `Dockerfile.dev`. The generated production `Dockerfile` is kept unchanged as a starting point for a real deployment ([ADR 3](docs/adr/0003-run-the-app-in-development-mode-via-docker-compose.md)).
- **Background jobs use Solid Queue**, backed by PostgreSQL rather than Redis, with its tables in a separate `queue` database. Recurring jobs are defined in `config/recurring.yml`.
- **Emails** are delivered by a small `:log` delivery method (`config/initializers/log_delivery.rb`) in development and production, as the brief allows. Switching to real delivery means replacing it with SMTP settings.

## Architecture decision records

Significant design decisions are recorded in [`docs/adr/`](docs/adr/), each with the alternatives considered and its consequences:

1. [Record architecture decisions](docs/adr/0001-record-architecture-decisions.md)
2. [Generate API-only application with minimal frameworks](docs/adr/0002-generate-api-only-application-with-minimal-frameworks.md)
3. [Run the app in development mode via Docker Compose](docs/adr/0003-run-the-app-in-development-mode-via-docker-compose.md)
4. [Organize code into domains with public interfaces](docs/adr/0004-organize-code-into-domains-with-public-interfaces.md)
5. [Use plain JSON with RFC 9457 errors and an OpenAPI contract](docs/adr/0005-use-plain-json-with-rfc-9457-errors-and-an-openapi-contract.md)
6. [Soft-delete books to keep borrowing history](docs/adr/0006-soft-delete-books-to-keep-borrowing-history.md)
7. [Model authors as authority records linked to books](docs/adr/0007-model-authors-as-authority-records-linked-to-books.md)
8. [Derive book status from the open borrowing](docs/adr/0008-derive-book-status-from-the-open-borrowing.md)
9. [Send return reminders from one daily job that records what was sent](docs/adr/0009-send-return-reminders-from-one-daily-job-that-records-what-was-sent.md)

New ADRs are created with a small generator:

```bash
docker compose exec web bin/rails g adr "Title" --status=Accepted
```

## Limitations and ideas for improvement

**Scope**

- **No authentication or authorization.** The task is scoped to internal staff use.
- **No endpoints for authors or readers yet.** Both come from seed data. Author endpoints would add a `sort_name` ("Herbert, Frank") for sorting by surname, and reader endpoints would let staff register readers.
- **No pagination or filtering on `GET /books`.** The response is wrapped in an object (`{"books": [...]}`), so pagination metadata can be added without a breaking change.
- **Deleted books can't be listed or restored through the API.** Their data is kept, but only visible in the database.

**Data model**

- **Author names are unique,** so two different authors with the same name can't both be stored. Library authority records tell them apart with life dates. The order of a book's authors isn't stored either; they're listed alphabetically.
- **Serial numbers are never reused,** even after a book is deleted, so a replacement copy needs a new number.
- **The library's time zone is fixed** (`config.time_zone`). Changing it would shift reminder days for existing loans.

**Reliability**

- **Deleting a book checks "is it borrowed?", then deletes.** A borrow landing between the two could lend a book that's being deleted. The window is milliseconds and needs two staff actions on the same book; closing it would take a lock or an application service spanning `Catalog` and `Lending`.
- **A reminder counts as sent once it's queued.** If its email job fails for good, the next daily run doesn't retry it. A delivery log per reminder would make that visible.
- **Emails are only logged.** Real delivery needs SMTP settings, and a mail catcher such as Mailpit could be added to Docker Compose for local testing.

**Architecture**

- **Domain boundaries are enforced only by convention.** [packwerk](https://github.com/Shopify/packwerk) could check them statically in CI. Foreign keys also couple the domains at the schema level: `Catalog` can't hard-delete a book that `Lending` references, and moving a domain to its own database would mean dropping its foreign keys.
- **Operations that span domains are coordinated in controllers.** As the app grows, application services or domain events would be a better fit.
- **A URL that matches no route gets Rails' default 404**, not a problem details response, because contract validation runs after routing.

**Deployment**

- **The Compose setup isn't production-ready.** It uses development server settings, hard-coded database credentials and no TLS.
