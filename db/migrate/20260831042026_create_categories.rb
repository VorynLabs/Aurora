class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.integer :position, null: false, default: 0 # ordem de exibição do filtro

      t.timestamps
    end

    add_index :categories, :slug, unique: true
  end
end
