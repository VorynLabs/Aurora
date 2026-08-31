FactoryBot.define do
  factory :order_item do
    order
    variant
    quantity { 1 }
    price_cents { 4_990 }
  end
end
