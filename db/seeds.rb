# Idempotent seed data, loaded by `bin/rails db:seed` and by `db:prepare` on a new database.

# Authors are authority records (ADR 0007). There are no author endpoints yet, so these
# are the authors books can be added with; their IDs appear in GET /books responses.
[
  "Frank Herbert",
  "Ursula K. Le Guin",
  "Stanisław Lem",
  "Andrzej Sapkowski",
  "George Orwell",
  "Jane Austen",
  "Fyodor Dostoevsky",
  "David Thomas",
  "Andrew Hunt",
  "Martin Fowler",
  "Kent Beck",
  "Sandi Metz"
].each { |name| Catalog::Author.find_or_create_by!(name:) }
