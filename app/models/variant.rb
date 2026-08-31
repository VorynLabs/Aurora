class Variant < ApplicationRecord
  belongs_to :product

  validates :name, presence: true
  validates :price_cents, :quantity, :reserved,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # disponível = estoque físico menos o que está reservado por pedidos pendentes
  def available_stock = quantity - reserved

  scope :available, -> { where("quantity - reserved >= 1") }

  # helpers de dinheiro
  def price = price_cents / 100.0
  def price_brl = format("R$ %.2f", price).sub(".", ",")
end
