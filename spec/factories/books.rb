FactoryBot.define do
  factory :book do
    sequence(:serial_number) { |n| format("%06d", n) }
    title { "The Sampled Sampler" }
    author { "Andrew Sampler" }

    trait :borrowed do
      after(:create) { |book| create(:borrowing, book: book) }
    end
  end
end
