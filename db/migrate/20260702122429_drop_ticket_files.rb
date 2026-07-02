class DropTicketFiles < ActiveRecord::Migration[7.2]
  def change
    drop_table :ticket_files
  end
end
