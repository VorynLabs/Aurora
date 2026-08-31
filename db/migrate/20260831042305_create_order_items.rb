class CreateOrderItems < ActiveRecord::Migration[7.1]
  def change
    create_table :order_items do |t|
      t.references :order,   null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.integer :quantity,    null: false # unidades desta variação no pedido
      t.integer :price_cents, null: false # preço NO MOMENTO da compra (histórico)

      t.timestamps
    end

    add_index :order_items, [:order_id, :variant_id], unique: true
  end
end
