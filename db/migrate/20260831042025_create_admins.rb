# Minimal admins table so products can carry a real foreign key from the start.
# Devise adds the authentication columns (encrypted_password and friends) in the
# next scope; creating the table here keeps products.admin_id a proper FK and
# lets the development seeds run without waiting for authentication.
class CreateAdmins < ActiveRecord::Migration[7.1]
  def change
    create_table :admins do |t|
      t.string :email, null: false

      t.timestamps
    end

    add_index :admins, :email, unique: true
  end
end
