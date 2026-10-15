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

```bash
bin/setup --skip-server         # install gems, prepare DB
bin/rails server                # or bin/dev
bin/jobs                        # Solid Queue worker/dispatcher/scheduler
bin/rubocop                     # lint (rubocop-rails-omakase)
bin/brakeman --no-pager         # security static analysis
bin/bundler-audit               # gem vulnerability audit
bin/ci                          # runs the steps in config/ci.rb
```

No test framework is installed yet: the app was generated with `-T`, and RSpec is planned. Once it is added, run `bundle exec rspec` (single file: `bundle exec rspec spec/path_spec.rb:LINE`) and add a test job to `.github/workflows/ci.yml` and `config/ci.rb`.

## Architecture notes

- Generated with `rails new . --api -d postgresql -T --skip-kamal --skip-thruster --skip-action-cable --skip-active-storage --skip-action-mailbox`. Don't reintroduce the skipped frameworks without a reason.
- Background jobs use Solid Queue, and recurring jobs are defined in `config/recurring.yml`. Out of the box, Solid Queue is only configured for production, with a separate `queue` database (`config/database.yml`, `config/environments/production.rb`). Running it in development and Docker needs explicit configuration.
- Planned design, not yet implemented: `books`, `readers` and `borrowings` tables. A book's status comes from its open borrowing (`returned_at IS NULL`), enforced by a partial unique index. Reminders come from one daily recurring job rather than delayed jobs per borrowing.

## Conventions

- Significant design decisions (real trade-offs) are recorded as ADRs in `docs/adr/` as numbered Markdown files (`0001-title.md`) with Context / Decision / Alternatives considered / Consequences. Read the existing ADRs before proposing changes, flag any proposal that contradicts an accepted ADR, and propose a new ADR when a decision has real trade-offs.
- The user prefers to run generators (`rails g ...`) themselves. Provide the command instead of running it unless asked.
- Before finishing a change, run `bin/rubocop` and the test suite.
