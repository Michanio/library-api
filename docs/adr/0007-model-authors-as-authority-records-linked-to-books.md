# 7. Model authors as authority records linked to books

Date: 2026-10-16
Status: Accepted

## Context

The brief describes a book's author as a plain attribute. Stored as free text typed in by library staff, the same author ends up written in several ways: with typos ("Frank Herbet"), in reversed order ("Herbert, Frank" next to "Frank Herbert"), or with different spacing and capitalisation. Finding all books by one author then becomes guesswork. Many books also have more than one author, which a single text field can only hold as an unstructured list.

Libraries solve this with authority control: each author has one canonical record, and catalogue entries point to it instead of repeating the name.

## Decision

Authors are records of their own in the `Catalog` domain, linked to books many-to-many.

- **`authors`** has a `name`, unique regardless of case (a unique index on `lower(name)`).
- **`book_authors`** links books and authors, with a unique pair and foreign keys on both sides.
- **Every book has at least one author.** Their order isn't stored; responses list them alphabetically.
- **The API refers to authors by ID.** `POST /books` takes `author_ids`, and an ID that matches no author fails with 422. Responses include `"authors": [{"id": ..., "name": ...}]`. Staff therefore choose from existing authors and can't introduce a new spelling while adding a book.
- **Author endpoints come later.** Until then, authors are created by the seed data, and their IDs can be found in `GET /books` responses or the seed list in the README.

## Alternatives considered

- **Keep the free-text `author` field, with whitespace normalised:** matches the brief exactly and needs no new tables, but does nothing against typos or reversed names.
- **An `authors` table, found or created by the name typed in `POST /books`:** easy to use, but a typo or reversed name silently creates a new author, so the problem stays.
- **Referring to authors by exact name in `POST /books`, rejecting unknown names:** protects against typos without needing IDs, but would have to change in a breaking way once author endpoints exist and clients work with IDs.
- **Separate first and last name fields:** fixes the reversed-order problem only, and doesn't fit single-name authors, pseudonyms, organisations as authors, or names where the family name comes first. Sorting by surname, the one real benefit, will instead come from a `sort_name` ("Herbert, Frank") added together with the author endpoints, as library catalogues do.
- **One author per book (`books.author_id`):** simpler, but wrong for the many books with several authors.

## Consequences

- (+) Each author is stored once, so books can reliably be grouped and, later, filtered by author.
- (+) Adding a book can't introduce a misspelt or reversed author name.
- (+) The schema and the `POST /books` contract are already in the shape that author endpoints will need.
- (−) Two more tables, and a join on every book read.
- (−) Until author endpoints exist, staff can only use authors from the seed data, and have to look up their IDs.
- (−) Two different authors with the same name can't both be stored. Library authority records tell them apart with life dates, which could be added later.
- (−) Author order on the title page isn't kept, so "Thomas, Hunt" and "Hunt, Thomas" read the same.
