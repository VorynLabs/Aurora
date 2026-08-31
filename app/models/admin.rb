class Admin < ApplicationRecord
  # Sem :registerable: não existe cadastro público de admin. Sem :recoverable:
  # a redefinição de senha é feita no console, já que hoje há um único admin.
  devise :database_authenticatable, :rememberable, :validatable

  has_many :products, dependent: :destroy
end
