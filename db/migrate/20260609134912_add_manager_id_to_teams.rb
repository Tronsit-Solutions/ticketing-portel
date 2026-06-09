class AddManagerIdToTeams < ActiveRecord::Migration[7.2]
  def change
    add_column :teams, :manager_id, :bigint
  end
end
