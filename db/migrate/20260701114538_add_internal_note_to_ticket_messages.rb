class AddInternalNoteToTicketMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :ticket_messages, :internal_note, :boolean, default: false, null: false
  end
end
