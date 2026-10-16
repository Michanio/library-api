# 8. Derive book status from the open borrowing

Date: 2026-10-16
Status: Accepted

## Context

For each book, the brief asks whether it's currently borrowed, when and by whom, together with its full borrowing history (borrow date, return date, reader). Staff change the status by borrowing and returning books. Each loan lasts 30 days, and reminders are based on the due date.

"Currently borrowed, when and by whom" is the same information as the latest borrowing that hasn't been returned. If the status were stored separately from the history, the two could disagree: a book marked available with an unreturned borrowing, or a book marked borrowed by one reader while the history shows another.

## Decision

The `Lending` domain owns a `borrowings` table, and a book's status is derived from it rather than stored.

- A borrowing records `book_id`, `reader_id`, `borrowed_at`, `due_on` and `returned_at`. It is **current** (open) while `returned_at IS NULL`.
- **A book is borrowed if and only if it has a current borrowing**, and that borrowing says by whom and since when. Otherwise it's available. There is no status column on `books`.
- **A partial unique index on `borrowings (book_id) WHERE returned_at IS NULL`** guarantees at most one current borrowing per book, even with concurrent requests. Borrowing a book that's out raises `Lending::BookAlreadyBorrowed`; a request that loses the race hits the index and gets the same error.
- Returning a book sets `returned_at` on its current borrowing, under a row lock, so two concurrent returns can't both succeed.
- **The full history is the book's borrowings**, current one included, newest first.
- **Loans last 30 days**: `due_on` is the borrow date plus 30 days. It's a calendar date in the library's time zone (`config.time_zone = "Europe/Warsaw"`), so a loan made just after midnight in Warsaw isn't dated the previous day, as it would be in UTC. Timestamps are still stored, and returned by the API, in UTC.
- Borrowings refer to books and readers by ID with foreign keys, but without Active Record associations across domains (ADR 4). Callers resolve serial numbers and library card numbers through `Catalog` and `Readers` first.

## Alternatives considered

- **A `status` column on `books`, plus a borrowings table for history:** status reads need no join, but every borrow and return has to update two tables consistently, and nothing in the database stops them disagreeing.
- **Only current-state columns on `books` (`borrowed_by`, `borrowed_at`):** the simplest model for the status, but it can't hold the history the brief requires.
- **Event sourcing (borrowed and returned events, status computed from them):** the history is complete by construction, but it's far more machinery than two state transitions need.
- **Due dates as UTC timestamps:** no time zone configuration, but "3 days before the due date" and "on the due date" are calendar days for readers, and a UTC date can be one day off for loans made around midnight.

## Consequences

- (+) Status and history can't contradict each other: there is one source of truth, and the database enforces the one-current-borrowing rule.
- (+) The history comes for free, and returned borrowings are never modified again.
- (+) The reminder job can find due loans with one indexed query on current borrowings by `due_on`.
- (−) Every status read needs the current borrowings. Listing books takes one extra query, batched for all listed books, instead of reading a column.
- (−) The rule "borrowed if it has a current borrowing" lives in one partial index and one scope. Code that queries `borrowings` without the `current` scope gets returned loans too.
- (−) The app now depends on a configured time zone. Moving the library to another zone would shift the dates of reminders for existing loans.
