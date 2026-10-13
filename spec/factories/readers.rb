FactoryBot.define do
  factory :reader do
    sequence(:card_number) { |n| format("%06d", 500_000 + n) }
    full_name { "Steven Sample" }
    sequence(:email) { |n| "reader#{n}@example.com" }
  end
end
