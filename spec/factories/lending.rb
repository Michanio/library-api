FactoryBot.define do
  # Lending refers to books and readers by ID only, so the factory creates them
  # unless IDs are given.
  factory :borrowing, class: "Lending::Borrowing" do
    book_id { create(:book).id }
    reader_id { create(:reader).id }
    borrowed_at { 1.day.ago }
    due_on { Lending::Borrowing.due_on_for(borrowed_at) }

    trait :returned do
      returned_at { borrowed_at + 1.hour }
    end
  end
end
