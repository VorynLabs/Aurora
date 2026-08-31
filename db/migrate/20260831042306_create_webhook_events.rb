class CreateWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :webhook_events do |t|
      t.string   :provider, null: false, default: "infinitepay"
      t.string   :event_id, null: false             # id único do evento no provedor
      t.string   :order_nsu
      t.integer  :status,   null: false, default: 0 # received/processed/ignored/failed
      t.jsonb    :payload,  null: false, default: {}
      t.datetime :processed_at

      t.timestamps
    end

    # Trava de idempotência: o mesmo evento nunca é processado duas vezes.
    add_index :webhook_events, [:provider, :event_id], unique: true
  end
end
