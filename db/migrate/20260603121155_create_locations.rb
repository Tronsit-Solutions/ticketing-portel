class CreateLocations < ActiveRecord::Migration[7.2]
  def change
    create_table :locations do |t|
      t.string  :name,         null: false
      t.string  :abbreviation, null: false
      t.string  :state,        null: false
      t.boolean :is_active,    null: false, default: true
      t.timestamps
    end

    add_index :locations, :name, unique: true
  end
end
