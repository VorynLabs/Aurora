FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Categoria #{n}" }
    position { 0 }
  end
end
