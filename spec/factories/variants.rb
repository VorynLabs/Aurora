FactoryBot.define do
  factory :variant do
    product
    sequence(:name) { |n| "Preta / #{n}" }
    price_cents { 4_990 }
    quantity { 10 }
    reserved { 0 }
  end
end
