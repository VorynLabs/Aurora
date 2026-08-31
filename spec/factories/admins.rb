FactoryBot.define do
  factory :admin do
    sequence(:email) { |n| "admin#{n}@aurora.local" }
    password { "senha-de-teste-123" }
  end
end
