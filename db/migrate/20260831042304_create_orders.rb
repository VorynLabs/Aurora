class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.string   :order_nsu, null: false             # id enviado à InfinitePay
      t.integer  :status,    null: false, default: 0 # enum: pending/paid/expired/canceled
      t.integer  :total_cents, null: false, default: 0
      t.string   :currency,    null: false, default: "BRL"
      t.string   :payment_link_url                   # link retornado pela InfinitePay
      t.string   :transaction_id                     # id da transação (vem no webhook)
      t.datetime :reserved_until                     # expira a reserva se não pago até aqui
      t.datetime :paid_at

      t.timestamps
    end

    add_index :orders, :order_nsu, unique: true
    add_index :orders, :status
  end
end
