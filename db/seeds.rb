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

# There are no reader endpoints yet, so these are the readers books can be lent to
# (POST /books/{serial_number}/borrow takes the library card number).
[
  { library_card_number: "000001", full_name: "Anna Kowalska", email: "anna.kowalska@example.com" },
  { library_card_number: "000002", full_name: "Jan Nowak", email: "jan.nowak@example.com" },
  { library_card_number: "000003", full_name: "Jane Doe", email: "jane.doe@example.com" },
  { library_card_number: "004217", full_name: "John Smith", email: "john.smith@example.com" },
  { library_card_number: "123456", full_name: "Maria Wiśniewska", email: "maria.wisniewska@example.com" }
].each do |attributes|
  Readers::Reader.find_or_create_by!(library_card_number: attributes[:library_card_number]) do |reader|
    reader.assign_attributes(attributes)
  end
end
