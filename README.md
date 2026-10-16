# Library API

A JSON API for library staff to manage books, lend and return them, and remind readers about due dates. Built with Rails 8.1 (API-only), Ruby 4.0 and PostgreSQL 17.

## Running the app

Requires Docker with the Compose plugin.

```bash
docker compose up
```

This starts PostgreSQL (`db`), the API on <http://localhost:3000> (`web`) and the background job worker (`jobs`). A new database is created, migrated and seeded automatically. The app is up when <http://localhost:3000/up> returns 200.

- **Interactive API docs:** <http://localhost:3000/docs> (Swagger UI for [`docs/openapi.yaml`](docs/openapi.yaml)).
- **Linux:** the container runs as UID/GID 1000. If yours differ (`id -u`, `id -g`), build first with `docker compose build --build-arg UID=$(id -u) --build-arg GID=$(id -g)`.

## Using the API

| Brief requirement | Endpoint |
|---|---|
| Add a new book | `POST /books` |
| Delete a book | `DELETE /books/{serial_number}` |
| List all books with their status | `GET /books` |
| Show a book with its full borrowing history | `GET /books/{serial_number}` |
| Update the book status: borrowed / available | `POST /books/{serial_number}/borrow` / `POST /books/{serial_number}/return` |

There are no endpoints for authors or readers yet, so they come from the seed data:

- **Authors (ID):** 1 Frank Herbert, 2 Ursula K. Le Guin, 3 Stanisław Lem, 4 Andrzej Sapkowski, 5 George Orwell, 6 Jane Austen, 7 Fyodor Dostoevsky, 8 David Thomas, 9 Andrew Hunt, 10 Martin Fowler, 11 Kent Beck, 12 Sandi Metz
- **Readers (library card):** 000001 Anna Kowalska, 000002 Jan Nowak, 000003 Jane Doe, 004217 John Smith, 123456 Maria Wiśniewska

```bash
curl -X POST localhost:3000/books -H 'Content-Type: application/json' \
  -d '{"serial_number": "000123", "title": "The Pragmatic Programmer", "author_ids": [8, 9]}'
curl -X POST localhost:3000/books/000123/borrow -H 'Content-Type: application/json' \
  -d '{"library_card_number": "004217"}'
curl localhost:3000/books                          # status, and who borrowed each book and when
curl -X POST localhost:3000/books/000123/return
curl localhost:3000/books/000123                   # the book with its borrowing history
curl -X DELETE localhost:3000/books/000123         # refused with 409 while the book is borrowed
```

Errors are [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem details (`application/problem+json`): 400 when the request doesn't match the contract, 404 for an unknown or deleted book, 409 when the book is in the wrong state, and 422 when a rule rejects the request (for example, a serial number that's taken). Invalid fields are listed with a JSON Pointer each.

## Return reminders

Loans last 30 days. A daily job (08:00 Europe/Warsaw) sends a reminder 3 days before the due date and another on the due date. Emails aren't actually sent; each one is written to the log.

- **Previews:** <http://localhost:3000/rails/mailers/lending/reminder_mailer>
- **Trigger one now** for a borrowed book, instead of waiting for 08:00:

  ```bash
  docker compose exec web bin/rails runner \
    'Lending::Borrowing.current.update_all(due_on: Date.current + 3); Lending::SendRemindersJob.perform_later'
  docker compose logs jobs | grep -A12 LogDelivery
  ```

## Tests and code quality

```bash
docker compose exec web bin/rails db:test:prepare   # once, and after new migrations
docker compose exec web bundle exec rspec
docker compose exec web bin/ci                      # RuboCop, RSpec, bundler-audit, Brakeman (as in GitHub Actions)
```

Request specs validate every request and response against `docs/openapi.yaml`. In CI (`OPENAPI_COVERAGE=strict`), the run also fails unless every documented response is exercised.

## Design decisions

Every significant decision is recorded as an ADR in [`docs/adr/`](docs/adr/), with the alternatives considered and its consequences.

## Limitations and ideas for improvement

- **No authentication or authorization**, as the brief allows.
- **No endpoints for authors or readers yet**, and no pagination on `GET /books`.
- **Deleted books are soft-deleted:** their history is kept, but they can't be listed or restored through the API, and their serial numbers can't be reused.
- **Emails are only logged.** Real delivery needs SMTP settings; a mail catcher such as Mailpit could be added for local testing.
- **Deleting a book while it's being borrowed** is checked, then executed, without a lock, leaving a milliseconds-wide race window.
- **Domain boundaries** (`app/domains/`) are enforced by convention only; packwerk could check them in CI.
- **The Compose setup isn't production-ready:** development settings, hard-coded credentials, no TLS.
