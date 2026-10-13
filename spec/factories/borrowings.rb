FactoryBot.define do
  factory :borrowing do
    book
    reader
    borrowed_at { Time.current }

    trait :returned do
      returned_at { borrowed_at + 7.days }
    end
  end
end
