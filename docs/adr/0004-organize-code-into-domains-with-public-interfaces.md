# 4. Organize code into domains with public interfaces

Date: 2026-10-15
Status: Accepted

## Context

The default Rails layout groups code by technical role (`app/models`, `app/jobs`, `app/mailers`). That works for small apps, but as an app grows, any class can reach into any other class's data, and the business areas are hard to see in the directory tree.

The task covers three distinct areas: the book catalogue, the readers who hold library cards, and lending (borrowing, returns, due dates and reminders). They change for different reasons, and some endpoints need data from more than one of them. For example, the book details endpoint shows the borrowing history together with reader data.

We want domain boundaries from the start, while it's cheap. The project is small, though, so the mechanism should add as little tooling and ceremony as possible.

## Decision

Domain code lives in `app/domains/<domain>/`. Zeitwerk treats every directory under `app/` as an autoload root, so `app/domains/catalog/book.rb` defines `Catalog::Book` with no extra configuration.

Domains:

| Domain | Owns | Responsibility |
|---|---|---|
| `Catalog` | `books` | Book identity: serial number, title, author |
| `Readers` | `readers` | Library card number, full name, email |
| `Lending` | `borrowings` | Borrowing and returning, due dates, borrowing history, reminder job and mailer |

Rules:

- **Each domain owns its tables and models.** Only the owning domain reads or writes its tables. Table names stay unprefixed (`books`, not `catalog_books`).
- **Each domain exposes a public interface** as module methods on the domain module itself, defined in `app/domains/<domain>.rb` (for example, `Lending.borrow(book_id:, reader_id:)`). Everything else inside the domain (models, queries, jobs) is private by convention.
- **Each interface method is a one-line delegation to a service object** in the domain directory, named after the operation (`Catalog.add_book` calls `Catalog::AddBook.call`), even when the operation itself is short. This keeps the interface readable as a list of what the domain offers, and gives every operation the same shape and its own spec. Service objects are private to the domain like everything else in it.
- **The public interface returns value objects (`Data.define`), not Active Record models.** Otherwise callers could update another domain's records through the returned object.
- **No Active Record associations across domains.** Domains refer to each other's records by ID. Database foreign keys are still used for integrity.
- **Dependencies point one way:** `Lending` may call `Catalog` and `Readers`. `Catalog` and `Readers` don't know about `Lending`.
- **Controllers are a separate HTTP layer** in `app/controllers` and don't belong to any domain. They call only public interfaces. When an endpoint needs data from several domains (book list with status, book details with history), the controller composes it. When an operation spans domains (refusing to delete a borrowed book), the controller coordinates it, so no domain needs to call back into `Lending`.
- Specs mirror the layout under `spec/domains/<domain>/`.

## Alternatives considered

- **Default Rails layout (`app/models`, ...):** least effort, but there are no boundaries at all, and the business areas don't show in the structure.
- **Packs with `packs-rails` and `packwerk`:** each domain becomes a package with declared dependencies, and privacy is checked statically in CI. This gives real enforcement, but adds two gems, `package.yml` files and a CI step. That's a lot of tooling for three small domains, and its compatibility with Ruby 4.0 wasn't verified. It's the natural next step if the boundaries need enforcing.
- **Rails engines per domain:** strong isolation, but each engine has its own gemspec, routes and migrations. That's far too heavy for this app.
- **Controllers inside each domain:** keeps everything about a domain in one place, but the endpoints don't map one-to-one onto domains. The book endpoints need `Lending` data, so a `Catalog` controller would depend on `Lending` and create a cycle.

## Consequences

- (+) The business areas are visible in the directory tree, and each domain's public interface shows what it offers.
- (+) Domains can be tested in isolation through their public interfaces.
- (+) Moving to packwerk later mostly means adding `package.yml` files, because the layout and rules already match.
- (−) Boundaries are enforced only by convention and code review. Nothing stops a controller or another domain from referencing `Catalog::Book` directly.
- (−) Returning value objects instead of models means some mapping code, and the HTTP layer makes more calls to compose responses.
- (−) Rails generators put files in the default directories (`rails g model Catalog::Book` writes to `app/models/catalog/`), so generated files have to be moved. For namespaced models the generator also adds a `table_name_prefix` module and a prefixed table name, which have to be removed.
- (−) Mailer templates still live in `app/views/<mailer_name>/`, outside the domain directory.
