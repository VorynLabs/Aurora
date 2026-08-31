FactoryBot.define do
  factory :admin do
    sequence(:email) { |n| "admin#{n}@aurora.local" }
  end
end
