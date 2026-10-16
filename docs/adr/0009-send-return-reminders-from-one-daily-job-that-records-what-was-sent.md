# 9. Send return reminders from one daily job that records what was sent

Date: 2026-10-16
Status: Accepted

## Context

Each loan lasts 30 days (ADR 8). The brief asks for two email reminders per loan: one 3 days before the due date and one on the due date. Real delivery isn't required; logging the email payload or a mailer preview is enough.

Reminders have to survive the ordinary failures of a background process: the `jobs` container can be down when a reminder is due, a job can be retried, and two workers can run at the same time. A reader shouldn't miss a reminder because of a restart, nor get the same reminder twice. A loan can also end early, when the book is returned, and then no further reminders should go out.

## Decision

One recurring job, `Lending::SendRemindersJob`, runs every day at 08:00 in the library's time zone (`config/recurring.yml`, Solid Queue). It calls `Lending::SendReminders`, which:

- selects current (unreturned) borrowings that need a reminder:
  - **due soon**: `due_on` within the next 3 days and `due_soon_reminder_sent_at` empty;
  - **due today**: `due_on` today or earlier and `due_today_reminder_sent_at` empty. A loan that's already due only gets this one;
- claims each reminder with a conditional update (`UPDATE ... SET <kind>_reminder_sent_at = now WHERE id = ? AND <kind>_reminder_sent_at IS NULL`), so only one of two concurrent runs sends it;
- queues the email with `deliver_later` in the same transaction as the claim, so a failure to queue rolls the claim back. Each email is its own job and is retried on its own.

Book titles and reader details come from `Catalog.list_books(ids:)` and `Readers.list_readers(ids:)`, one query each for the whole run.

Emails are text-only (`Lending::ReminderMailer`, `due_soon` and `due_today`). The `due_today` reminder says when the book was due if it's sent late. In development and production they are delivered by `LogDelivery`, which writes them to the Rails log instead of sending them; the `jobs` service logs to STDOUT, so they appear in `docker compose logs jobs`. Mailer previews show them at `/rails/mailers`.

## Alternatives considered

- **Stateless daily selection (`due_on = today + 3`, `due_on = today`):** no extra columns, but a second run on the same day sends duplicates, and a day the job doesn't run loses that day's reminders for good.
- **Two delayed jobs per borrowing, scheduled when the book is borrowed (`set(wait_until:)`):** no polling, but the jobs have to be cancelled or checked when the book is returned early, rescheduled if the loan period or time zone changes, and they're invisible in the database. Thousands of open loans mean thousands of scheduled jobs.
- **A separate `reminders` table with one row per reminder:** a full delivery history and room for more reminder kinds, but more schema than two fixed reminders need.
- **Delivering by SMTP to a local catcher (MailHog, Mailpit) in Docker Compose:** realistic, but another service to run, and the brief explicitly accepts logging.

## Consequences

- (+) Running the job twice sends nothing new, and reminders missed while the job wasn't running go out on the next run. A due-soon reminder is still sent up to the day before the due date.
- (+) Concurrent runs can't send the same reminder twice.
- (+) Returned books drop out of the selection automatically.
- (+) Which reminders were sent, and when, is visible on each borrowing.
- (−) Two more columns on `borrowings`, and the schedule's resolution is one day: a reminder is sent at 08:00, not at the exact moment.
- (−) A reminder is marked as sent when it's queued, not when it's delivered. If the email job fails for good, the reminder isn't retried by the next daily run.
- (−) The daily job scans current borrowings. The partial index on `due_on WHERE returned_at IS NULL` keeps that cheap, but it's still a query per day rather than event-driven work.
