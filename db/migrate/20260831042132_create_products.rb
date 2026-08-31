class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.references :admin,    null: false, foreign_key: true # dono (multi-tenant futuro)
      t.references :category, null: false, foreign_key: true
      t.string  :title,       null: false
      t.text    :description
      t.boolean :hidden_by_admin, null: false, default: false # ocultação manual

      t.timestamps
    end

    add_index :products, [:admin_id, :title]
  end
end
