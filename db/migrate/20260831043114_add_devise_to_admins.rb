# A tabela admins já existe desde o escopo do modelo de dados, com email e
# índice único. Aqui entram só as colunas que o Devise precisa para os módulos
# em uso: database_authenticatable e rememberable.
class AddDeviseToAdmins < ActiveRecord::Migration[7.1]
  def change
    change_table :admins, bulk: true do |t|
      t.string   :encrypted_password, null: false, default: ""
      t.datetime :remember_created_at
    end
  end
end
