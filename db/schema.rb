# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_16_194238) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "authors", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_authors_on_lower_name", unique: true
  end

  create_table "book_authors", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_book_authors_on_author_id"
    t.index ["book_id", "author_id"], name: "index_book_authors_on_book_id_and_author_id", unique: true
  end

  create_table "books", force: :cascade do |t|
    t.string "serial_number", limit: 6, null: false
    t.string "title", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["serial_number"], name: "index_books_on_serial_number", unique: true
    t.check_constraint "serial_number::text ~ '^[0-9]{6}$'::text", name: "books_serial_number_six_digits"
  end

  add_foreign_key "book_authors", "authors"
  add_foreign_key "book_authors", "books"
end
