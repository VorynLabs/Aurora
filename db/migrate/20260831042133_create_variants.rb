class CreateVariants < ActiveRecord::Migration[7.1]
  def change
    create_table :variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string  :name,        null: false          # ex.: "Preta / P" — rótulo humano
      t.string  :sku
      t.integer :price_cents, null: false          # preço EM CENTAVOS (evita float)
      t.string  :currency,    null: false, default: "BRL"
      t.integer :quantity,    null: false, default: 0 # ESTOQUE vive aqui
      t.integer :reserved,    null: false, default: 0 # segurado por pedidos pendentes

      t.timestamps
    end

    add_index :variants, :sku, unique: true, where: "sku IS NOT NULL"
    add_index :variants, [:product_id, :name]
  end
end
