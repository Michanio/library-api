FactoryBot.define do
  factory :reader, class: "Readers::Reader" do
    sequence(:library_card_number) { |n| format("%06d", n) }
    full_name { "Jane Doe" }
    sequence(:email) { |n| "reader#{n}@example.com" }
  end
end
