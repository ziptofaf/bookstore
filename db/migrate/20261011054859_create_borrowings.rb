class CreateBorrowings < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowings do |t|
      t.references :book, null: false, foreign_key: true
      t.references :reader, null: false, foreign_key: true
      t.datetime :borrowed_at, null: false
      t.date :due_date, null: false
      t.datetime :returned_at
      t.datetime :due_soon_reminder_sent_at
      t.datetime :due_today_reminder_sent_at

      t.timestamps
    end
    # A book can only be lent to one reader at a time.
    add_index :borrowings, :book_id, unique: true, where: "returned_at IS NULL", name: "index_borrowings_on_book_id_active"
    # The daily reminder jobs look up active borrowings by due date; a partial index keeps it small.
    add_index :borrowings, :due_date, where: "returned_at IS NULL", name: "index_borrowings_on_due_date_active"
  end
end
