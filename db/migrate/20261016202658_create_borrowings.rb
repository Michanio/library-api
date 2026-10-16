class CreateBorrowings < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowings do |t|
      t.references :book, null: false, foreign_key: true
      t.references :reader, null: false, foreign_key: true
      t.datetime :borrowed_at, null: false
      t.date :due_on, null: false
      t.datetime :returned_at

      t.timestamps
    end
    # A book's status is derived from its open borrowing (ADR 0008), so a book can
    # have at most one.
    add_index :borrowings, :book_id, unique: true, where: "returned_at IS NULL", name: "index_borrowings_on_book_id_open"
    # The daily reminder job looks up open borrowings by due date.
    add_index :borrowings, :due_on, where: "returned_at IS NULL", name: "index_borrowings_on_due_on_open"
    add_check_constraint :borrowings, "returned_at IS NULL OR returned_at >= borrowed_at", name: "borrowings_returned_after_borrowed"
  end
end
