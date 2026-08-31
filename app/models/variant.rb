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

  # --- PREÇO EM REAIS (campo virtual do formulário) ---
  # O admin digita "49,90"; o banco guarda 4990. price_cents continua sendo a
  # fonte da verdade — dinheiro nunca vira float.
  def price_reais
    return @price_reais if defined?(@price_reais)
    return nil if price_cents.blank?

    format("%.2f", price).tr(".", ",")
  end

  def price_reais=(value)
    @price_reais = value
    self.price_cents = self.class.cents_from_reais(value)
  end

  # Aceita "49,90", "49.90", "R$ 49,90" e "1.234,56". Devolve nil no que não dá
  # para ler — a validação de price_cents é quem reclama, com mensagem de campo.
  def self.cents_from_reais(value)
    return nil if value.blank?

    digits = value.to_s.strip.delete("R$").gsub(/\s/, "")
    digits = if digits.include?(",")
      digits.delete(".").tr(",", ".")          # "1.234,56" -> "1234.56"
    elsif digits.match?(/\A-?\d{1,3}(\.\d{3})+\z/)
      digits.delete(".")                       # "1.234" -> "1234"
    else
      digits                                   # "49.90" -> decimal mesmo
    end

    return nil unless digits.match?(/\A-?\d+(\.\d+)?\z/)

    (BigDecimal(digits) * 100).round.to_i
  end
end
