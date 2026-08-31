class Admin < ApplicationRecord
  has_many :products, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }
end
