class AddQ5Q6ModifierToHiringDetails < ActiveRecord::Migration[7.2]
  def change
    add_column :hiring_details, :q5_q6_modifier, :string
  end
end
