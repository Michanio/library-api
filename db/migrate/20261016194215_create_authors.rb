class CreateAuthors < ActiveRecord::Migration[8.1]
  def change
    create_table :authors do |t|
      t.string :name, null: false

      t.timestamps
    end
    # Authors are authority records (ADR 0007): one record per name, regardless of case.
    add_index :authors, "lower(name)", unique: true, name: "index_authors_on_lower_name"
  end
end
