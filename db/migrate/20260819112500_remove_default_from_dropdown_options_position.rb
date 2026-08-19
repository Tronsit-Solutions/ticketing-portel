class RemoveDefaultFromDropdownOptionsPosition < ActiveRecord::Migration[7.2]
  def change
    change_column_default :dropdown_options, :position, from: 0, to: nil
  end
end
