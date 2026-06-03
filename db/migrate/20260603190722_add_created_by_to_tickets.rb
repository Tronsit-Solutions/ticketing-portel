class AddCreatedByToTickets < ActiveRecord::Migration[7.2]
  def change
    add_reference :tickets, :created_by, null: true, foreign_key: { to_table: :users }
  end
end
