class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_error

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  before_validation :set_slug, if: -> { slug.blank? && name.present? }

  scope :ordered, -> { order(:position, :name) }

  private

  def set_slug = self.slug = name.parameterize
end
