class CreateBookAuthors < ActiveRecord::Migration[8.1]
  def change
    create_table :book_authors do |t|
      # The unique index below starts with book_id, so it also serves lookups by book.
      t.references :book, null: false, foreign_key: true, index: false
      t.references :author, null: false, foreign_key: true

      t.timestamps
    end
    add_index :book_authors, [ :book_id, :author_id ], unique: true
  end
end
