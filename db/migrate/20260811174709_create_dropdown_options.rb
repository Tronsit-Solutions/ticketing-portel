class CreateDropdownOptions < ActiveRecord::Migration[7.2]
  def change
    create_table :dropdown_options do |t|
      t.string  :category,  null: false
      t.string  :label,     null: false
      t.string  :value
      t.integer :position,  null: false, default: 0
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :dropdown_options, :category
    add_index :dropdown_options, [:category, :is_active]
    add_index :dropdown_options, [:category, :value], unique: true
  end
end
