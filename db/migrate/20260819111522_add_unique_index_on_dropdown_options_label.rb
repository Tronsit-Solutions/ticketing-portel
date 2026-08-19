class AddUniqueIndexOnDropdownOptionsLabel < ActiveRecord::Migration[7.2]
  def change
    add_index :dropdown_options, [:category, :label], unique: true
  end
end
