class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :serial_number, null: false
      t.string :title, null: false
      t.string :author, null: false

      t.timestamps
    end
    add_index :books, :serial_number, unique: true
    add_check_constraint :books, "serial_number ~ '^[0-9]{6}$'", name: "books_serial_number_six_digits"
  end
end
