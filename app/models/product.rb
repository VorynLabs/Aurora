class Product < ApplicationRecord
  belongs_to :admin
  belongs_to :category
  has_many   :variants, dependent: :destroy
  has_one_attached :image

  accepts_nested_attributes_for :variants, allow_destroy: true,
    reject_if: ->(attrs) { attrs[:name].blank? && attrs[:price_cents].blank? }

  validates :title, presence: true
  validate  :must_have_at_least_one_variant

  # --- REGRA CANÔNICA DE VISIBILIDADE NO CATÁLOGO ---
  # Um produto aparece no catálogo se NÃO foi ocultado manualmente
  # E possui ao menos uma variação com estoque disponível (>= 1).
  scope :visible_in_catalog, -> {
    where(hidden_by_admin: false)
      .where(id: Variant.available.select(:product_id))
      .distinct
  }

  def visible_in_catalog?
    !hidden_by_admin && variants.any? { |v| v.available_stock >= 1 }
  end

  def min_price_cents = variants.available.minimum(:price_cents) || variants.minimum(:price_cents)

  private

  def must_have_at_least_one_variant
    return if variants.reject(&:marked_for_destruction?).any?

    errors.add(:base, "produto precisa de ao menos uma variação")
  end
end
