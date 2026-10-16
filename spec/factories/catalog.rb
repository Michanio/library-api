FactoryBot.define do
  factory :author, class: "Catalog::Author" do
    sequence(:name) { |n| "Author #{n}" }
  end

  factory :book, class: "Catalog::Book" do
    sequence(:serial_number) { |n| format("%06d", n) }
    title { "Dune" }
    authors { [ association(:author) ] }

    trait :deleted do
      deleted_at { 1.day.ago }
    end
  end
end
