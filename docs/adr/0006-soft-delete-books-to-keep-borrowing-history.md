# 6. Soft-delete books to keep borrowing history

Date: 2026-10-16
Status: Accepted

## Context

The brief asks for an endpoint that deletes a book, and separately for each book's full borrowing history (borrow date, return date, reader). A library removes books from its collection for ordinary reasons: a copy is lost, damaged or withdrawn. Who borrowed the book and when is still worth keeping after that, for example to follow up on a lost copy with its last reader.

Borrowings refer to books by foreign key (ADR 4). Deleting a book row would have to either cascade to its borrowings, losing the history, or be blocked by them, so that most books could never be deleted.

## Decision

Books are soft-deleted. `DELETE /books/{serial_number}` sets `books.deleted_at` instead of removing the row.

- A deleted book disappears from the API: it isn't listed, and every request addressing it returns 404, just as if it had never existed.
- Its borrowings stay in the database untouched.
- A borrowed book can't be deleted (409 `book-borrowed`), so a deleted book never has an open borrowing and never gets reminders.
- **Serial numbers are never reused.** The unique index on `books.serial_number` covers deleted books too, so creating a book with a deleted book's serial number fails with 422 "has already been taken". A serial number therefore always identifies one physical copy, and so does its history.
- Queries filter deleted books explicitly with an `active` scope on `Catalog::Book`. There is no `default_scope`, because a hidden filter leaks into associations and `unscoped` calls in ways that are easy to miss.

## Alternatives considered

- **Hard delete with cascade:** simplest, and it fully meets the brief, but the borrowing history is lost with the book.
- **Hard delete, refused while any borrowing exists:** keeps the history safe without a new column, but almost every book that was ever lent could never be deleted.
- **Allowing serial numbers to be reused after deletion** (a partial unique index `WHERE deleted_at IS NULL`): a new copy could take over an old label, but then one serial number would refer to different books over time, and their histories could be confused.
- **A gem such as `discard` or `paranoia`:** `paranoia` relies on `default_scope`, with the problems above. `discard` is close to what we need, but it would only replace a scope and two small methods.

## Consequences

- (+) Borrowing history survives deletion, and every borrowing still points at an existing book row.
- (+) A serial number identifies one physical book for its whole life.
- (−) Every query for books has to remember `active`. Forgetting it would show deleted books.
- (−) A deleted book's serial number can't be used again, even for a replacement copy.
- (−) There's no API to list or restore deleted books. Their data is only visible in the database.
