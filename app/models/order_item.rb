class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :variant

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
