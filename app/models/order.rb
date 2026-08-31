class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :variants, through: :order_items

  enum :status, { pending: 0, paid: 1, expired: 2, canceled: 3 }

  validates :order_nsu, presence: true, uniqueness: true

  before_validation :generate_order_nsu, on: :create

  scope :stale_pending, -> { pending.where("reserved_until < ?", Time.current) }

  private

  def generate_order_nsu = self.order_nsu ||= "ord_#{SecureRandom.hex(12)}"
end
