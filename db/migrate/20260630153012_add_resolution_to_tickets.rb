class AddResolutionToTickets < ActiveRecord::Migration[7.2]
  def change
    add_column :tickets, :resolution, :text
  end
end
