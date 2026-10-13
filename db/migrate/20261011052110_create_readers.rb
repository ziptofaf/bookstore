class CreateReaders < ActiveRecord::Migration[8.1]
  def change
    create_table :readers do |t|
      t.string :card_number, null: false
      t.string :full_name, null: false
      t.string :email, null: false

      t.timestamps
    end
    add_index :readers, :card_number, unique: true
    add_index :readers, :email, unique: true
    add_check_constraint :readers, "card_number ~ '^[0-9]{6}$'", name: "readers_card_number_six_digits"
  end
end
