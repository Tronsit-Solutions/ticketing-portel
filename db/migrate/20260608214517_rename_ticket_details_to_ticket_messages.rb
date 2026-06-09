class RenameTicketDetailsToTicketMessages < ActiveRecord::Migration[7.2]
  def change
    rename_table :ticket_details, :ticket_messages
  end
end
