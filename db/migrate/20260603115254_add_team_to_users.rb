class AddTeamToUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :users, :team, null: true, foreign_key: true
  end
end
